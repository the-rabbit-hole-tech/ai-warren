// Package answers holds what a person or an unattended config tells warren: the machine's role,
// the tools, the GitHub identity for the guard, the secret store, and the marketplaces and plugins to
// install. The interactive init, `warren init --config` and the skills all fill the same struct,
// and every step reads only from it.
//
// Answers never hold a secret. They name where a secret comes from (an environment variable, a
// secret-store path), and loading rejects anything that looks like a secret value.
package answers

/*
Apache License 2.0

Copyright 2026 The ai-warren Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"

	"github.com/goccy/go-yaml"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

// Defaults filled in when the answers leave a field out.
const (
	DefaultMarketplace = "ai-warren"
	DefaultPlugin      = "warren@ai-warren"
)

// DefaultTools are the tools "this machine" installs when the answers name none.
var DefaultTools = []string{"tmux", "gh", "claude"}

// Roles a machine can have.
var Roles = []string{"ops", "contributor", "agent-machine"}

// Answers is the whole set of answers. Field names match the YAML and JSON keys.
type Answers struct {
	Host         HostAnswers    `yaml:"host" json:"host"`
	Version      int            `yaml:"version" json:"version"`
	Role         string         `yaml:"role" json:"role"`
	Tools        []string       `yaml:"tools" json:"tools"`
	GitHub       GitHubAnswers  `yaml:"github" json:"github"`
	Secrets      SecretsAnswers `yaml:"secrets" json:"secrets"`
	Marketplaces []string       `yaml:"marketplaces" json:"marketplaces"`
	Plugins      []string       `yaml:"plugins" json:"plugins"`
	OrgPlugins   []string       `yaml:"org_plugins" json:"org_plugins"`
	Repo         RepoAnswers    `yaml:"repo" json:"repo"`
}

// GitHubAnswers is the identity the guard allows on this machine, and where the gh token comes
// from.
type GitHubAnswers struct {
	Login    string `yaml:"login" json:"login"`
	Name     string `yaml:"name" json:"name"`
	Email    string `yaml:"email" json:"email"`
	TokenEnv string `yaml:"token_env" json:"token_env"`
	Signing  string `yaml:"signing" json:"signing"`
	Guard    string `yaml:"guard" json:"guard"`
}

// SecretsAnswers says whether a password manager is used and which secret paths the role may inject.
type SecretsAnswers struct {
	Enabled     bool     `yaml:"enabled" json:"enabled"`
	URL         string   `yaml:"url" json:"url"`
	SecretPaths []string `yaml:"secret_paths" json:"secret_paths"`
}

// Load reads answers from a YAML file. It rejects a secret-looking value with
// WARREN-CONFIG-SECRET and anything else wrong with WARREN-CONFIG-INVALID.
func Load(path string) (Answers, error) {
	data, err := os.ReadFile(path) // #nosec G304 -- the person names their own answers file
	if err != nil {
		return Answers{}, codes.Wrap(codes.ConfigInvalid, err, "read answers")
	}
	var raw any
	if err := yaml.Unmarshal(data, &raw); err != nil {
		return Answers{}, codes.New(codes.ConfigInvalid, "%s is not valid YAML: %s", path, yamlMessage(err))
	}
	if err := checkSecrets("", raw); err != nil {
		return Answers{}, err
	}
	var a Answers
	if err := yaml.UnmarshalWithOptions(data, &a, yaml.Strict()); err != nil {
		return Answers{}, codes.New(codes.ConfigInvalid, "%s: %s", path, yamlMessage(err))
	}
	return finish(a)
}

// FromJSON reads answers as JSON, the form `warren step --answers -` takes on stdin.
func FromJSON(r io.Reader) (Answers, error) {
	data, err := io.ReadAll(r)
	if err != nil {
		return Answers{}, codes.Wrap(codes.ConfigInvalid, err, "read answers")
	}
	var raw any
	if err := json.Unmarshal(data, &raw); err != nil {
		return Answers{}, codes.New(codes.ConfigInvalid, "answers are not valid JSON")
	}
	if err := checkSecrets("", raw); err != nil {
		return Answers{}, err
	}
	var a Answers
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&a); err != nil {
		return Answers{}, codes.New(codes.ConfigInvalid, "answers JSON: %s", err.Error())
	}
	return finish(a)
}

// FromJSONFile reads answers saved as JSON, such as the copy init keeps for doctor.
func FromJSONFile(path string) (Answers, error) {
	f, err := os.Open(path) // #nosec G304 -- warren's own saved answers, or a file the person names
	if err != nil {
		return Answers{}, codes.Wrap(codes.ConfigInvalid, err, "read saved answers")
	}
	defer func() { _ = f.Close() }()
	return FromJSON(f)
}

// Save writes a as JSON to path, making its folder. Answers never hold a secret, so the copy is
// safe to keep; it is still written owner-only.
func Save(path string, a Answers) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return codes.Wrap(codes.FileFailed, err, "make "+filepath.Dir(path))
	}
	data, err := json.MarshalIndent(a, "", "  ")
	if err != nil {
		return codes.Wrap(codes.FileFailed, err, "encode answers")
	}
	if err := os.WriteFile(path, append(data, '\n'), 0o600); err != nil {
		return codes.Wrap(codes.FileFailed, err, "write "+path)
	}
	return nil
}

// WithDefaults fills the fields the answers left out.
func (a Answers) WithDefaults() Answers {
	if a.Version == 0 {
		a.Version = 1
	}
	if a.Tools == nil {
		a.Tools = slices.Clone(DefaultTools)
	}
	if a.Marketplaces == nil {
		a.Marketplaces = []string{DefaultMarketplace}
	}
	if a.Plugins == nil {
		a.Plugins = []string{DefaultPlugin}
	}
	if a.GitHub.Signing == "" {
		a.GitHub.Signing = "none"
	}
	if a.GitHub.Guard == "" {
		a.GitHub.Guard = "per-host"
	}
	return a
}

// Validate checks the values that have a fixed set of choices.
func (a Answers) Validate() error {
	if a.Version != 1 {
		return codes.New(codes.ConfigInvalid, "version %d is not supported (want 1)", a.Version)
	}
	if a.Role != "" && !slices.Contains(Roles, a.Role) {
		return codes.New(codes.ConfigInvalid, "role %q is not one of %s", a.Role, strings.Join(Roles, ", "))
	}
	if !slices.Contains([]string{"none", "ssh"}, a.GitHub.Signing) {
		return codes.New(codes.ConfigInvalid, "github.signing %q is not none or ssh", a.GitHub.Signing)
	}
	if a.GitHub.Guard != "per-host" {
		return codes.New(codes.ConfigInvalid, "github.guard %q: the guard is always per-host", a.GitHub.Guard)
	}
	return nil
}

func finish(a Answers) (Answers, error) {
	a = a.WithDefaults()
	if err := a.Validate(); err != nil {
		return Answers{}, err
	}
	return a, nil
}

// secretField matches a field name that would hold a secret value. Names that only point at a
// secret, such as token_env or secret_paths, do not match.
var secretField = regexp.MustCompile(`(?i)^(.*[_-])?(token|password|passwd|key|secret|apikey)$`)

// secretValue matches values that look like a credential whatever field they sit in.
var secretValue = regexp.MustCompile(`(gh[pousr]_[A-Za-z0-9]{1,}|github_pat_[A-Za-z0-9_]{8,}|sk-ant-[A-Za-z0-9_-]{8,}|glpat-[A-Za-z0-9_-]{8,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----|xox[abprs]-[A-Za-z0-9-]{8,})`)

// checkSecrets walks the decoded document. The error names the field, never the value.
func checkSecrets(at string, v any) error {
	switch t := v.(type) {
	case map[string]any:
		for k, child := range t {
			p := joinPath(at, k)
			if secretField.MatchString(k) && hasValue(child) {
				return codes.New(codes.ConfigSecret, "%s holds a literal value; name where it comes from instead (an env var or a secret-store path)", p)
			}
			if err := checkSecrets(p, child); err != nil {
				return err
			}
		}
	case []any:
		for i, child := range t {
			if err := checkSecrets(fmt.Sprintf("%s[%d]", at, i), child); err != nil {
				return err
			}
		}
	case string:
		if secretValue.MatchString(t) {
			return codes.New(codes.ConfigSecret, "%s looks like a secret value; answers only name where secrets come from", at)
		}
	}
	return nil
}

func hasValue(v any) bool {
	switch t := v.(type) {
	case nil:
		return false
	case string:
		return t != ""
	case []any:
		return len(t) > 0
	case map[string]any:
		return len(t) > 0
	default:
		return true
	}
}

func joinPath(at, k string) string {
	if at == "" {
		return k
	}
	return at + "." + k
}

// yamlMessage keeps the parser's message but drops the source excerpt it prints, so a value never
// reaches the terminal or the logs through an error.
func yamlMessage(err error) string {
	if m, ok := err.(interface{ GetMessage() string }); ok {
		return m.GetMessage()
	}
	return "parse error"
}
