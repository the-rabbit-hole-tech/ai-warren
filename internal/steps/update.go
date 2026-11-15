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
	"os"
	"path/filepath"
	"sort"
	"strings"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

// Update refreshes the ai-warren marketplace and updates every installed ai-warren plugin whose
// version is behind it, in every scope it's installed in. It runs only when asked for (the
// /warren menu's "update warren", or `warren step update`), never as part of init or doctor.
type Update struct{ env Env }

// Name implements Step.
func (s *Update) Name() string { return "update" }

// marketplaceVersions reads the version of each plugin in the local copy of the marketplace.
func (s *Update) marketplaceVersions(ctx context.Context, claude string) (map[string]string, error) {
	res, err := s.env.run(ctx, claude, "plugin", "marketplace", "list", "--json")
	if err != nil {
		return nil, codes.Wrap(codes.ExecFailed, err, "list marketplaces")
	}
	var markets []struct {
		Name            string `json:"name"`
		InstallLocation string `json:"installLocation"`
	}
	if err := json.Unmarshal([]byte(res.Stdout), &markets); err != nil {
		return nil, codes.Wrap(codes.StepFailed, err, "read the marketplace list")
	}
	root := ""
	for _, m := range markets {
		if m.Name == answers.DefaultMarketplace {
			root = m.InstallLocation
		}
	}
	if root == "" {
		return nil, codes.New(codes.MarketplaceUnknown, "the %s marketplace isn't added; run the marketplace step first", answers.DefaultMarketplace)
	}
	var manifest struct {
		Plugins []struct {
			Name   string `json:"name"`
			Source any    `json:"source"`
		} `json:"plugins"`
	}
	if err := readJSONFile(filepath.Join(root, ".claude-plugin", "marketplace.json"), &manifest); err != nil {
		return nil, err
	}
	out := map[string]string{}
	for _, p := range manifest.Plugins {
		src, ok := p.Source.(string)
		if !ok || !strings.HasPrefix(src, "./") {
			continue
		}
		var pj struct {
			Version string `json:"version"`
		}
		if err := readJSONFile(filepath.Join(root, src, ".claude-plugin", "plugin.json"), &pj); err != nil {
			s.env.Log.Debug("plugin not in the local marketplace copy", golog.F("plugin", p.Name))
			continue
		}
		out[p.Name+"@"+answers.DefaultMarketplace] = pj.Version
	}
	return out, nil
}

func readJSONFile(path string, v any) error {
	body, err := os.ReadFile(path) // #nosec G304 -- files inside the marketplace copy
	if err != nil {
		return codes.Wrap(codes.FileFailed, err, "read "+path)
	}
	if err := json.Unmarshal(body, v); err != nil {
		return codes.Wrap(codes.FileFailed, err, "parse "+path)
	}
	return nil
}

// behind lists the installed ai-warren plugins whose version differs from the marketplace copy.
func (s *Update) behind(ctx context.Context) ([]installedPlugin, string, error) {
	claude, ok := s.env.claudePath()
	if !ok {
		return nil, "", codes.New(codes.ClaudeMissing, "the claude CLI is not installed; the tools step installs it")
	}
	versions, err := s.marketplaceVersions(ctx, claude)
	if err != nil {
		return nil, claude, err
	}
	list, err := s.env.installedPlugins(ctx)
	if err != nil {
		return nil, claude, err
	}
	var out []installedPlugin
	for _, p := range list {
		if want, ok := versions[p.ID]; ok && want != p.Version {
			out = append(out, p)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID+out[i].Scope < out[j].ID+out[j].Scope })
	return out, claude, nil
}

func names(ps []installedPlugin) string {
	var n []string
	for _, p := range ps {
		n = append(n, p.ID+" ("+p.Scope+")")
	}
	return strings.Join(n, ", ")
}

// Check implements Step. It compares against the local marketplace copy as last refreshed.
func (s *Update) Check(ctx context.Context, _ answers.Answers) (Status, error) {
	behind, _, err := s.behind(ctx)
	if err != nil {
		return StatusMissing, err
	}
	if len(behind) > 0 {
		return StatusDrift, codes.New(codes.UpdateAvailable, "behind the marketplace: %s", names(behind))
	}
	return StatusOK, nil
}

// Apply implements Step.
func (s *Update) Apply(ctx context.Context, _ answers.Answers) (Result, error) {
	claude, ok := s.env.claudePath()
	if !ok {
		return Result{}, codes.New(codes.ClaudeMissing, "the claude CLI is not installed; the tools step installs it")
	}
	s.env.Log.Info("refreshing marketplace", golog.F("marketplace", answers.DefaultMarketplace))
	if _, err := s.env.run(ctx, claude, "plugin", "marketplace", "update", answers.DefaultMarketplace, "--json"); err != nil {
		return Result{}, codes.Wrap(codes.ExecFailed, err, "update marketplace "+answers.DefaultMarketplace)
	}
	behind, _, err := s.behind(ctx)
	if err != nil {
		return Result{}, err
	}
	if len(behind) == 0 {
		return Result{Message: "marketplace refreshed; every installed ai-warren plugin is current"}, nil
	}
	for _, p := range behind {
		s.env.Log.Info("updating plugin", golog.F("plugin", p.ID), golog.F("scope", p.Scope), golog.F("from", p.Version))
		c := sysexec.Command{Name: claude, Args: []string{"plugin", "update", p.ID, "--scope", p.Scope, "--json"}}
		if p.Scope == "project" || p.Scope == "local" {
			c.Dir = p.ProjectPath
		}
		if _, err := s.env.Exec.Run(ctx, c); err != nil {
			return Result{}, codes.Wrap(codes.ExecFailed, err, "update plugin "+p.ID)
		}
	}
	return Result{Changed: true, Message: "updated " + names(behind) + "; run /reload-plugins or restart to load them"}, nil
}
