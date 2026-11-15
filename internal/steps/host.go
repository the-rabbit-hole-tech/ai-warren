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
	_ "embed" // the host file template
	"os"
	"path/filepath"
	"strings"
	"text/template"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

// hostTemplate is a copy of hosts/_template/CLAUDE.host.md; a test keeps the two identical.
//
//go:embed templates/CLAUDE.host.md.tmpl
var hostTemplate string

// Host writes this machine's host file from the template and the host answers. It only ever
// writes the one file at Host.Path, and never overwrites a file that differs.
type Host struct{ env Env }

// Name implements Step.
func (s *Host) Name() string { return "host" }

func (s *Host) path(a answers.Answers) string {
	if a.Host.Path != "" {
		return a.Host.Path
	}
	return filepath.Join(s.env.Home, ".claude", "CLAUDE.host.md")
}

func (s *Host) render(h answers.HostAnswers) (string, error) {
	var missing []string
	for _, f := range []struct{ name, v string }{{"code_root", h.CodeRoot}, {"git_account", h.GitAccount}, {"git_email", h.GitEmail}, {"name", h.Name}} {
		if f.v == "" {
			missing = append(missing, f.name)
		}
	}
	if len(missing) > 0 {
		return "", codes.New(codes.ConfigInvalid, "host.%s is required to write the host file", strings.Join(missing, ", host."))
	}
	if h.GitHost == "" {
		h.GitHost = "github.com"
	}
	t, err := template.New("host").Funcs(template.FuncMap{"join": strings.Join}).Option("missingkey=error").Parse(hostTemplate)
	if err != nil {
		return "", codes.Wrap(codes.FileFailed, err, "parse the host template")
	}
	var buf bytes.Buffer
	if err := t.Execute(&buf, h); err != nil {
		return "", codes.Wrap(codes.FileFailed, err, "render the host template")
	}
	return buf.String(), nil
}

// compare renders the file and reports its status against what is on disk.
func (s *Host) compare(a answers.Answers) (Status, string, error) {
	if a.Host.Empty() {
		return StatusSkipped, "", nil
	}
	want, err := s.render(a.Host)
	if err != nil {
		return "", "", err
	}
	path := s.path(a)
	have, err := os.ReadFile(path) // #nosec G304 -- the path the person gave for their own host file
	if os.IsNotExist(err) {
		return StatusMissing, want, codes.New(codes.StepFailed, "%s does not exist", path)
	}
	if err != nil {
		return "", "", codes.Wrap(codes.FileFailed, err, "read "+path)
	}
	if string(have) == want {
		return StatusOK, want, nil
	}
	return StatusDrift, want, codes.New(codes.StepFailed, "%s differs from the host answers", path)
}

// Check implements Step.
func (s *Host) Check(_ context.Context, a answers.Answers) (Status, error) {
	st, _, err := s.compare(a)
	return st, err
}

// Apply implements Step.
func (s *Host) Apply(_ context.Context, a answers.Answers) (Result, error) {
	st, want, err := s.compare(a)
	path := s.path(a)
	switch st {
	case StatusSkipped:
		return Result{Message: "no host answers given; nothing written"}, nil
	case StatusOK:
		return Result{Message: path + " already matches"}, nil
	case StatusDrift:
		s.env.Log.Warn("host file differs; left alone", golog.F("path", path))
		return Result{Message: path + " differs from the host answers; left unchanged (edit it by hand or move it aside)"}, nil
	case StatusMissing:
		if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
			return Result{}, codes.Wrap(codes.FileFailed, err, "make "+filepath.Dir(path))
		}
		if err := os.WriteFile(path, []byte(want), 0o600); err != nil {
			return Result{}, codes.Wrap(codes.FileFailed, err, "write "+path)
		}
		s.env.Log.Info("wrote host file", golog.F("path", path))
		return Result{Changed: true, Message: "wrote " + path}, nil
	}
	return Result{}, err
}
