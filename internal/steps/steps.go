// Package steps holds every setup step warren runs. Each step checks one thing on this machine
// and can bring it in line with the answers. The interactive init, `warren init --config`,
// `warren step` and `warren doctor` all run these same steps; no other place holds step logic.
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
	"os"
	"path/filepath"
	"runtime"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

// Status is what a Check found.
type Status string

// The statuses a Check returns.
const (
	StatusOK      Status = "ok"      // in line with the answers
	StatusMissing Status = "missing" // not set up yet; Apply sets it up
	StatusDrift   Status = "drift"   // set up differently; Apply changes nothing
	StatusSkipped Status = "skipped" // not wanted by these answers
)

// Result is what an Apply did.
type Result struct {
	Changed bool   `json:"changed"`
	Message string `json:"message"`
}

// Step is one setup step.
type Step interface {
	Name() string
	// Check looks without changing anything. A non-nil error with a status says why.
	Check(ctx context.Context, a answers.Answers) (Status, error)
	// Apply brings this machine in line with a. It is safe to run again.
	Apply(ctx context.Context, a answers.Answers) (Result, error)
}

// DefaultMarketplaceSource is where the ai-warren marketplace is added from.
const DefaultMarketplaceSource = "the-rabbit-hole-tech/ai-warren"

// Env is everything a step reads from the machine. Tests replace each part.
type Env struct {
	Exec   sysexec.Exec
	GOOS   string
	Home   string
	Getenv func(string) string
	IsRoot bool
	// MarketplaceSource is where the ai-warren marketplace is added from: owner/repo, a git URL
	// or a local directory.
	MarketplaceSource string
	// AllowIdentityChange lets guard-identity replace a different identity already set. Without
	// it a different identity is reported as drift and left alone.
	AllowIdentityChange bool
	Log                 golog.TraceLogger
}

// DefaultEnv is the Env of the running process.
func DefaultEnv(log golog.TraceLogger) Env {
	home, _ := os.UserHomeDir()
	src := os.Getenv("WARREN_MARKETPLACE_SOURCE")
	if src == "" {
		src = DefaultMarketplaceSource
	}
	return Env{
		Exec:              sysexec.New(log),
		GOOS:              runtime.GOOS,
		Home:              home,
		Getenv:            os.Getenv,
		IsRoot:            os.Geteuid() == 0,
		MarketplaceSource: src,
		Log:               log,
	}
}

func (e Env) withDefaults() Env {
	if e.Log == nil {
		e.Log = golog.Nop()
	}
	if e.Getenv == nil {
		e.Getenv = func(string) string { return "" }
	}
	if e.MarketplaceSource == "" {
		e.MarketplaceSource = DefaultMarketplaceSource
	}
	return e
}

// RegistryFor returns every step, in the order init runs them, bound to env.
func RegistryFor(env Env) []Step {
	env = env.withDefaults()
	return []Step{
		&Host{env: env},
		&Tools{env: env},
		&Marketplace{env: env},
		&Plugins{env: env},
		&GuardIdentity{env: env},
		&GuardSync{env: env},
		&GHAuth{env: env},
		&Path{env: env},
		&LessonsLog{env: env},
	}
}

// OnDemandFor returns the steps that run only when asked for by name (`warren step <name>`),
// never as part of `warren init` or `warren doctor`.
func OnDemandFor(env Env) []Step {
	return []Step{
		&RepoSettings{env: env},
		&Update{env: env},
	}
}

// AllFor returns the registry and the on-demand steps, for finding a step by name.
func AllFor(env Env) []Step {
	return append(RegistryFor(env), OnDemandFor(env)...)
}

// Registry returns every step bound to this process's environment.
func Registry() []Step {
	return RegistryFor(DefaultEnv(golog.Nop()))
}

// Find returns the step named name.
func Find(all []Step, name string) (Step, error) {
	for _, s := range all {
		if s.Name() == name {
			return s, nil
		}
	}
	return nil, codes.New(codes.StepUnknown, "no step named %q", name)
}

// Groups maps each `warren init --only` group to the steps it runs.
var Groups = map[string][]string{
	"host":    {"host"},
	"machine": {"tools", "marketplace", "plugins", "guard-identity", "guard-sync", "path", "lessons-log"},
	"github":  {"gh-auth"},
	"secrets": {},
}

// claudePath finds the claude CLI on PATH, or where the official installer puts it.
func (e Env) claudePath() (string, bool) {
	if p, err := e.Exec.LookPath("claude"); err == nil {
		return p, true
	}
	if p, err := e.Exec.LookPath(filepath.Join(e.Home, ".local", "bin", "claude")); err == nil {
		return p, true
	}
	return "", false
}

func (e Env) run(ctx context.Context, name string, args ...string) (sysexec.Result, error) {
	return e.Exec.Run(ctx, sysexec.Command{Name: name, Args: args})
}
