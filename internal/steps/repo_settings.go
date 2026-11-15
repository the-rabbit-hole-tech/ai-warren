package steps

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
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"slices"
	"sort"
	"strings"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

// RepoSettings declares a repo's marketplaces and plugins in its settings and installs them for
// the repo. A public repo gets `.claude/settings.local.json` (kept out of git), any other repo
// `.claude/settings.json`. Existing keys are kept in their order; a marketplace already declared
// with another source is drift and is left alone.
type RepoSettings struct{ env Env }

// Name implements Step.
func (s *RepoSettings) Name() string { return "repo-settings" }

const localSettings = ".claude/settings.local.json"

type repoPlan struct {
	path      string
	scope     string
	public    bool
	markets   map[string]string // name -> owner/repo
	plugins   []string
	settings  *orderedJSON
	addMarket []string
	addPlugin []string
	install   []string
	ignore    bool // settings.local.json needs a local git exclude
}

// marketplaceDecl is the extraKnownMarketplaces entry for a marketplace source: owner/repo is a
// GitHub repo, a URL or git@ address a git source, and a path a local directory.
func marketplaceDecl(src string) map[string]any {
	switch {
	case strings.Contains(src, "://") || strings.HasPrefix(src, "git@"):
		return map[string]any{"source": map[string]any{"source": "git", "url": src}}
	case strings.HasPrefix(src, "/") || strings.HasPrefix(src, ".") || strings.HasPrefix(src, "~"):
		return map[string]any{"source": map[string]any{"source": "directory", "path": src}}
	}
	return map[string]any{"source": map[string]any{"source": "github", "repo": src}}
}

func validateRepo(r answers.RepoAnswers) error {
	if r.Dir == "" {
		return codes.New(codes.RepoInvalid, "repo.dir is required")
	}
	if fi, err := os.Stat(r.Dir); err != nil || !fi.IsDir() {
		return codes.New(codes.RepoInvalid, "repo.dir %s is not a folder", r.Dir)
	}
	if !slices.Contains(answers.Visibilities, r.Visibility) {
		return codes.New(codes.RepoInvalid, "repo.visibility %q is not one of %s", r.Visibility, strings.Join(answers.Visibilities, ", "))
	}
	for _, p := range r.Plugins {
		name, market, ok := strings.Cut(p, "@")
		if !ok || name == "" {
			return codes.New(codes.RepoInvalid, "plugin %q is not <plugin>@<marketplace>", p)
		}
		if market != answers.DefaultMarketplace && r.Marketplaces[market] == "" {
			return codes.New(codes.RepoInvalid, "plugin %q names marketplace %q, which repo.marketplaces doesn't give", p, market)
		}
	}
	return nil
}

func (s *RepoSettings) plan(ctx context.Context, a answers.Answers) (*repoPlan, error) {
	r := a.Repo
	if err := validateRepo(r); err != nil {
		return nil, err
	}
	p := &repoPlan{public: r.Visibility == "public", scope: "project", markets: map[string]string{answers.DefaultMarketplace: s.env.MarketplaceSource}}
	p.path = filepath.Join(r.Dir, ".claude", "settings.json")
	if p.public {
		p.path = filepath.Join(r.Dir, localSettings)
		p.scope = "local"
	}
	for k, v := range r.Marketplaces {
		p.markets[k] = v
	}
	p.plugins = append([]string{answers.DefaultPlugin}, r.Plugins...)
	p.plugins = slices.Compact(p.plugins)

	settings, err := readOrderedJSON(p.path)
	if err != nil {
		return nil, err
	}
	p.settings = settings

	known := map[string]any{}
	_ = settings.get("extraKnownMarketplaces", &known)
	names := make([]string, 0, len(p.markets))
	for n := range p.markets {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, n := range names {
		cur, ok := known[n]
		if !ok {
			p.addMarket = append(p.addMarket, n)
			continue
		}
		want := marketplaceDecl(p.markets[n])
		if !jsonEqual(cur, want) {
			return p, codes.New(codes.RepoSettingsDrift, "%s already declares marketplace %q with another source; change it by hand if that's wrong", p.path, n)
		}
	}
	enabled := map[string]any{}
	_ = settings.get("enabledPlugins", &enabled)
	for _, id := range p.plugins {
		if enabled[id] != true {
			p.addPlugin = append(p.addPlugin, id)
		}
	}

	list, err := s.env.installedPlugins(ctx)
	if err != nil {
		return nil, err
	}
	abs, _ := filepath.Abs(r.Dir)
	have := map[string]bool{}
	for _, ip := range list {
		if ip.Scope == p.scope && (ip.ProjectPath == abs || ip.ProjectPath == r.Dir) {
			have[ip.ID] = true
		}
	}
	for _, id := range p.plugins {
		if !have[id] {
			p.install = append(p.install, id)
		}
	}

	if p.public {
		if _, err := s.env.run(ctx, "git", "-C", r.Dir, "check-ignore", "-q", localSettings); err != nil {
			if sysexec.ExitCode(err) != 1 {
				return nil, codes.Wrap(codes.ExecFailed, err, "check whether git ignores "+localSettings)
			}
			p.ignore = true
		}
	}
	s.env.Log.Debug("repo settings planned", golog.F("path", p.path), golog.F("scope", p.scope),
		golog.F("add_marketplaces", strings.Join(p.addMarket, ",")), golog.F("add_plugins", strings.Join(p.addPlugin, ",")),
		golog.F("install", strings.Join(p.install, ",")), golog.F("exclude", p.ignore))
	return p, nil
}

func (p *repoPlan) done() bool {
	return len(p.addMarket) == 0 && len(p.addPlugin) == 0 && len(p.install) == 0 && !p.ignore
}

func (p *repoPlan) summary() string {
	var parts []string
	if len(p.addMarket) > 0 {
		parts = append(parts, "declare marketplaces "+strings.Join(p.addMarket, ", "))
	}
	if len(p.addPlugin) > 0 {
		parts = append(parts, "enable "+strings.Join(p.addPlugin, ", "))
	}
	if len(p.install) > 0 {
		parts = append(parts, "install at "+p.scope+" scope "+strings.Join(p.install, ", "))
	}
	if p.ignore {
		parts = append(parts, "keep "+localSettings+" out of git locally")
	}
	return strings.Join(parts, "; ")
}

// Check implements Step.
func (s *RepoSettings) Check(ctx context.Context, a answers.Answers) (Status, error) {
	if a.Repo.Dir == "" {
		return StatusSkipped, nil
	}
	p, err := s.plan(ctx, a)
	if codes.Is(err, codes.RepoSettingsDrift) {
		return StatusDrift, err
	}
	if err != nil {
		return StatusMissing, err
	}
	if !p.done() {
		return StatusMissing, codes.New(codes.RepoNotSetUp, "%s: %s", p.path, p.summary())
	}
	return StatusOK, nil
}

// Apply implements Step.
func (s *RepoSettings) Apply(ctx context.Context, a answers.Answers) (Result, error) {
	p, err := s.plan(ctx, a)
	if err != nil {
		return Result{}, err
	}
	if p.done() {
		return Result{Message: p.path + " already declares " + strings.Join(p.plugins, ", ")}, nil
	}
	summary := p.summary()
	if len(p.addMarket) > 0 || len(p.addPlugin) > 0 {
		known := map[string]any{}
		_ = p.settings.get("extraKnownMarketplaces", &known)
		for _, n := range p.addMarket {
			known[n] = marketplaceDecl(p.markets[n])
		}
		enabled := map[string]any{}
		_ = p.settings.get("enabledPlugins", &enabled)
		for _, id := range p.addPlugin {
			enabled[id] = true
		}
		if err := p.settings.set("extraKnownMarketplaces", known); err != nil {
			return Result{}, err
		}
		if err := p.settings.set("enabledPlugins", enabled); err != nil {
			return Result{}, err
		}
		if err := p.settings.write(p.path); err != nil {
			return Result{}, err
		}
		s.env.Log.Info("repo settings written", golog.F("path", p.path))
	}
	if p.ignore {
		if err := s.excludeLocal(ctx, a.Repo.Dir); err != nil {
			return Result{}, err
		}
	}
	claude, _ := s.env.claudePath()
	for _, id := range p.install {
		s.env.Log.Info("installing plugin for the repo", golog.F("plugin", id), golog.F("scope", p.scope), golog.F("dir", a.Repo.Dir))
		c := sysexec.Command{Name: claude, Args: []string{"plugin", "install", id, "--scope", p.scope, "--json"}, Dir: a.Repo.Dir}
		if _, err := s.env.Exec.Run(ctx, c); err != nil {
			return Result{}, codes.Wrap(codes.ExecFailed, err, "install plugin "+id)
		}
	}
	return Result{Changed: true, Message: p.path + ": " + summary}, nil
}

// excludeLocal adds the local settings file to the repo's own .git/info/exclude, which is never
// committed, so a public repo's settings never reach a commit.
func (s *RepoSettings) excludeLocal(ctx context.Context, dir string) error {
	res, err := s.env.run(ctx, "git", "-C", dir, "rev-parse", "--git-path", "info/exclude")
	if err != nil {
		return codes.Wrap(codes.ExecFailed, err, "find the repo's info/exclude")
	}
	path := strings.TrimSpace(res.Stdout)
	if !filepath.IsAbs(path) {
		path = filepath.Join(dir, path)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
		return codes.Wrap(codes.FileFailed, err, "make "+filepath.Dir(path))
	}
	f, err := os.OpenFile(path, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600) // #nosec G304 -- the repo's own exclude file
	if err != nil {
		return codes.Wrap(codes.FileFailed, err, "open "+path)
	}
	defer func() { _ = f.Close() }()
	if _, err := f.WriteString("\n# warren: plugin settings stay local in a public repo\n" + localSettings + "\n"); err != nil {
		return codes.Wrap(codes.FileFailed, err, "write "+path)
	}
	return nil
}

func jsonEqual(a, b any) bool {
	x, err1 := json.Marshal(a)
	y, err2 := json.Marshal(b)
	return err1 == nil && err2 == nil && bytes.Equal(x, y)
}

// orderedJSON is a JSON object that keeps its keys in the order they were read, so rewriting a
// settings file doesn't reshuffle what the repo already had.
type orderedJSON struct {
	keys  []string
	vals  map[string]json.RawMessage
	dirty map[string]bool // keys set here; the rest are written back exactly as read
}

func readOrderedJSON(path string) (*orderedJSON, error) {
	o := &orderedJSON{vals: map[string]json.RawMessage{}, dirty: map[string]bool{}}
	body, err := os.ReadFile(path) // #nosec G304 -- the repo's own settings file
	if errors.Is(err, os.ErrNotExist) {
		return o, nil
	}
	if err != nil {
		return nil, codes.Wrap(codes.FileFailed, err, "read "+path)
	}
	dec := json.NewDecoder(bytes.NewReader(body))
	if t, err := dec.Token(); err != nil || t != json.Delim('{') {
		return nil, codes.New(codes.RepoInvalid, "%s is not a JSON object", path)
	}
	for dec.More() {
		t, err := dec.Token()
		if err != nil {
			return nil, codes.New(codes.RepoInvalid, "%s is not valid JSON", path)
		}
		key, _ := t.(string)
		var raw json.RawMessage
		if err := dec.Decode(&raw); err != nil {
			return nil, codes.New(codes.RepoInvalid, "%s is not valid JSON", path)
		}
		if _, seen := o.vals[key]; !seen {
			o.keys = append(o.keys, key)
		}
		o.vals[key] = raw
	}
	return o, nil
}

func (o *orderedJSON) get(key string, v any) error {
	raw, ok := o.vals[key]
	if !ok {
		return nil
	}
	return json.Unmarshal(raw, v)
}

func (o *orderedJSON) set(key string, v any) error {
	raw, err := json.Marshal(v)
	if err != nil {
		return codes.Wrap(codes.FileFailed, err, "encode "+key)
	}
	if _, ok := o.vals[key]; !ok {
		o.keys = append(o.keys, key)
	}
	o.vals[key] = raw
	o.dirty[key] = true
	return nil
}

func (o *orderedJSON) write(path string) error {
	var b bytes.Buffer
	b.WriteString("{\n")
	for i, k := range o.keys {
		kj, _ := json.Marshal(k)
		var v bytes.Buffer
		if o.dirty[k] {
			if err := json.Indent(&v, o.vals[k], "  ", "  "); err != nil {
				return codes.Wrap(codes.FileFailed, err, "format "+k)
			}
		} else {
			v.Write(o.vals[k])
		}
		b.WriteString("  ")
		b.Write(kj)
		b.WriteString(": ")
		b.Write(v.Bytes())
		if i < len(o.keys)-1 {
			b.WriteString(",")
		}
		b.WriteString("\n")
	}
	b.WriteString("}\n")
	if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
		return codes.Wrap(codes.FileFailed, err, "make "+filepath.Dir(path))
	}
	if err := os.WriteFile(path, b.Bytes(), 0o644); err != nil { // #nosec G306 -- repo settings are not secret
		return codes.Wrap(codes.FileFailed, err, "write "+path)
	}
	return nil
}
