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
	"context"
	"encoding/json"
	"strings"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

// Plugins installs the answers' plugins and org plugins at user scope. An installed plugin is
// never installed again.
type Plugins struct{ env Env }

// Name implements Step.
func (s *Plugins) Name() string { return "plugins" }

// installedPlugin is one entry of `claude plugin list --json`.
type installedPlugin struct {
	ID             string `json:"id"`
	Version        string `json:"version"`
	Scope          string `json:"scope"`
	Enabled        bool   `json:"enabled"`
	InstallPath    string `json:"installPath"`
	ReadFromFolder string `json:"readFromFolder"`
	ProjectPath    string `json:"projectPath"`
}

// installedPlugins reads `claude plugin list --json`.
func (e Env) installedPlugins(ctx context.Context) ([]installedPlugin, error) {
	claude, ok := e.claudePath()
	if !ok {
		return nil, codes.New(codes.ClaudeMissing, "the claude CLI is not installed; the tools step installs it")
	}
	res, err := e.run(ctx, claude, "plugin", "list", "--json")
	if err != nil {
		return nil, codes.Wrap(codes.ExecFailed, err, "list plugins")
	}
	var list []installedPlugin
	if err := json.Unmarshal([]byte(res.Stdout), &list); err != nil {
		return nil, codes.Wrap(codes.StepFailed, err, "read the plugin list")
	}
	return list, nil
}

func wantedPlugins(a answers.Answers) []string {
	return append(append([]string{}, a.Plugins...), a.OrgPlugins...)
}

func (s *Plugins) missing(ctx context.Context, a answers.Answers) ([]string, error) {
	list, err := s.env.installedPlugins(ctx)
	if err != nil {
		return nil, err
	}
	have := map[string]bool{}
	for _, p := range list {
		if p.Scope == "user" {
			have[p.ID] = true
		}
	}
	var out []string
	for _, id := range wantedPlugins(a) {
		if !have[id] {
			out = append(out, id)
		}
	}
	s.env.Log.Debug("plugins checked", golog.F("wanted", strings.Join(wantedPlugins(a), ",")), golog.F("missing", strings.Join(out, ",")))
	return out, nil
}

// Check implements Step.
func (s *Plugins) Check(ctx context.Context, a answers.Answers) (Status, error) {
	missing, err := s.missing(ctx, a)
	if err != nil {
		return StatusMissing, err
	}
	if len(missing) > 0 {
		return StatusMissing, codes.New(codes.PluginMissing, "not installed at user scope: %s", strings.Join(missing, ", "))
	}
	return StatusOK, nil
}

// Apply implements Step.
func (s *Plugins) Apply(ctx context.Context, a answers.Answers) (Result, error) {
	missing, err := s.missing(ctx, a)
	if err != nil {
		return Result{}, err
	}
	if len(missing) == 0 {
		return Result{Message: "already installed: " + strings.Join(wantedPlugins(a), ", ")}, nil
	}
	claude, _ := s.env.claudePath()
	for _, id := range missing {
		s.env.Log.Info("installing plugin", golog.F("plugin", id), golog.F("scope", "user"))
		if _, err := s.env.run(ctx, claude, "plugin", "install", id, "--scope", "user", "--json"); err != nil {
			return Result{}, codes.Wrap(codes.ExecFailed, err, "install plugin "+id)
		}
	}
	return Result{Changed: true, Message: "installed " + strings.Join(missing, ", ")}, nil
}
