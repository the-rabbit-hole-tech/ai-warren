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
	"strings"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

// claudeInstaller is the official claude installer, run through bash.
const claudeInstaller = "curl -fsSL https://claude.ai/install.sh | bash"

// Tools installs the tools the answers name (tmux, gh and claude by default): brew on macOS,
// apt-get on Linux (through sudo when not root), and the official installer for claude.
type Tools struct{ env Env }

// Name implements Step.
func (s *Tools) Name() string { return "tools" }

func (s *Tools) missing(a answers.Answers) []string {
	var out []string
	for _, tool := range a.Tools {
		found := false
		if tool == "claude" {
			_, found = s.env.claudePath()
		} else {
			_, err := s.env.Exec.LookPath(tool)
			found = err == nil
		}
		s.env.Log.Trace("tool check", golog.F("tool", tool), golog.F("found", found))
		if !found {
			out = append(out, tool)
		}
	}
	return out
}

// Check implements Step.
func (s *Tools) Check(_ context.Context, a answers.Answers) (Status, error) {
	if m := s.missing(a); len(m) > 0 {
		return StatusMissing, codes.New(codes.StepFailed, "not installed: %s", strings.Join(m, ", "))
	}
	return StatusOK, nil
}

// Apply implements Step.
func (s *Tools) Apply(ctx context.Context, a answers.Answers) (Result, error) {
	missing := s.missing(a)
	if len(missing) == 0 {
		return Result{Message: "all installed"}, nil
	}
	s.env.Log.Info("installing tools", golog.F("tools", strings.Join(missing, ",")), golog.F("os", s.env.GOOS))

	var packages []string
	claude := false
	for _, t := range missing {
		if t == "claude" {
			claude = true
			continue
		}
		packages = append(packages, t)
	}
	if len(packages) > 0 {
		if err := s.installPackages(ctx, packages); err != nil {
			return Result{}, err
		}
	}
	if claude {
		s.env.Log.Info("installing claude with the official installer")
		if _, err := s.env.run(ctx, "bash", "-c", claudeInstaller); err != nil {
			return Result{}, codes.Wrap(codes.ExecFailed, err, "install claude")
		}
	}
	if still := s.missing(a); len(still) > 0 {
		return Result{}, codes.New(codes.StepFailed, "still not found after installing: %s", strings.Join(still, ", "))
	}
	return Result{Changed: true, Message: "installed " + strings.Join(missing, ", ")}, nil
}

func (s *Tools) installPackages(ctx context.Context, packages []string) error {
	switch s.env.GOOS {
	case "darwin":
		if _, err := s.env.Exec.LookPath("brew"); err != nil {
			return codes.New(codes.ToolsNoPackager, "Homebrew is not installed; install it from https://brew.sh, then run warren init again")
		}
		for _, p := range packages {
			if _, err := s.env.run(ctx, "brew", "install", p); err != nil {
				return codes.Wrap(codes.ExecFailed, err, "brew install "+p)
			}
		}
		return nil
	case "linux":
		if _, err := s.env.Exec.LookPath("apt-get"); err != nil {
			return codes.New(codes.ToolsNoPackager, "apt-get is not available; install %s by hand", strings.Join(packages, ", "))
		}
		prefix := []string{}
		if !s.env.IsRoot {
			if _, err := s.env.Exec.LookPath("sudo"); err != nil {
				return codes.New(codes.ToolsNoPackager, "not root and sudo is not installed; install %s by hand", strings.Join(packages, ", "))
			}
			prefix = []string{"sudo"}
		}
		apt := func(args ...string) error {
			full := append(append([]string{}, prefix...), append([]string{"apt-get"}, args...)...)
			_, err := s.env.Exec.Run(ctx, sysexec.Command{Name: full[0], Args: full[1:], Env: []string{"DEBIAN_FRONTEND=noninteractive"}})
			return err
		}
		if err := apt("update"); err != nil {
			return codes.Wrap(codes.ExecFailed, err, "apt-get update")
		}
		for _, p := range packages {
			if err := apt("install", "-y", p); err != nil {
				return codes.Wrap(codes.ExecFailed, err, "apt-get install "+p)
			}
		}
		return nil
	default:
		return codes.New(codes.ToolsNoPackager, "no installer for %s; install %s by hand", s.env.GOOS, strings.Join(packages, ", "))
	}
}
