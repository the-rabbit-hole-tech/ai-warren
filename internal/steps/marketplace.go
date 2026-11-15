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
	"slices"
	"strings"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

// Marketplace adds the marketplaces the answers name with `claude plugin marketplace add`. Only
// ai-warren has a known source (Env.MarketplaceSource); an added marketplace is never added again.
type Marketplace struct{ env Env }

// Name implements Step.
func (s *Marketplace) Name() string { return "marketplace" }

type listedMarketplace struct {
	Name   string `json:"name"`
	Source string `json:"source"`
}

func (s *Marketplace) listed(ctx context.Context, claude string) ([]string, error) {
	res, err := s.env.run(ctx, claude, "plugin", "marketplace", "list", "--json")
	if err != nil {
		return nil, codes.Wrap(codes.ExecFailed, err, "list marketplaces")
	}
	var list []listedMarketplace
	if err := json.Unmarshal([]byte(res.Stdout), &list); err != nil {
		return nil, codes.Wrap(codes.StepFailed, err, "read the marketplace list")
	}
	names := make([]string, 0, len(list))
	for _, m := range list {
		names = append(names, m.Name)
	}
	return names, nil
}

func (s *Marketplace) missing(ctx context.Context, a answers.Answers) (string, []string, error) {
	claude, ok := s.env.claudePath()
	if !ok {
		return "", nil, codes.New(codes.ClaudeMissing, "the claude CLI is not installed; the tools step installs it")
	}
	names, err := s.listed(ctx, claude)
	if err != nil {
		return claude, nil, err
	}
	var out []string
	for _, want := range a.Marketplaces {
		if !slices.Contains(names, want) {
			out = append(out, want)
		}
	}
	s.env.Log.Debug("marketplaces checked", golog.F("listed", strings.Join(names, ",")), golog.F("missing", strings.Join(out, ",")))
	return claude, out, nil
}

// Check implements Step.
func (s *Marketplace) Check(ctx context.Context, a answers.Answers) (Status, error) {
	_, missing, err := s.missing(ctx, a)
	if err != nil {
		return StatusMissing, err
	}
	if len(missing) > 0 {
		return StatusMissing, codes.New(codes.StepFailed, "not added: %s", strings.Join(missing, ", "))
	}
	return StatusOK, nil
}

// Apply implements Step.
func (s *Marketplace) Apply(ctx context.Context, a answers.Answers) (Result, error) {
	claude, missing, err := s.missing(ctx, a)
	if err != nil {
		return Result{}, err
	}
	if len(missing) == 0 {
		return Result{Message: "already added: " + strings.Join(a.Marketplaces, ", ")}, nil
	}
	for _, name := range missing {
		if name != answers.DefaultMarketplace {
			return Result{}, codes.New(codes.MarketplaceUnknown, "no source is known for marketplace %q; add it with claude plugin marketplace add", name)
		}
	}
	for _, name := range missing {
		src := s.env.MarketplaceSource
		s.env.Log.Info("adding marketplace", golog.F("marketplace", name), golog.F("source", src))
		res, err := s.env.run(ctx, claude, "plugin", "marketplace", "add", src, "--json")
		if err != nil {
			return Result{}, codes.Wrap(codes.ExecFailed, err, "add marketplace "+name)
		}
		var out struct {
			Outcome     string `json:"outcome"`
			Marketplace string `json:"marketplace"`
		}
		if err := json.Unmarshal([]byte(lastJSONLine(res.Stdout)), &out); err != nil {
			return Result{}, codes.Wrap(codes.StepFailed, err, "read the marketplace add result")
		}
		if out.Marketplace != name {
			return Result{}, codes.New(codes.StepFailed, "source %s holds marketplace %q, not %q", src, out.Marketplace, name)
		}
	}
	return Result{Changed: true, Message: "added " + strings.Join(missing, ", ")}, nil
}

// lastJSONLine returns the last line of out that starts with "{": claude's --json result line
// comes last on stdout.
func lastJSONLine(out string) string {
	lines := strings.Split(strings.TrimSpace(out), "\n")
	for i := len(lines) - 1; i >= 0; i-- {
		if l := strings.TrimSpace(lines[i]); strings.HasPrefix(l, "{") {
			return l
		}
	}
	return ""
}
