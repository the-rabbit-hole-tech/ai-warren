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

// GuardIdentity sets the one git identity this machine allows, in the global git config the
// guard reads. The values come only from Answers.GitHub, never from another machine. A different
// identity already set is drift and is left alone unless Env.AllowIdentityChange says otherwise:
// an identity change is never a side effect.
type GuardIdentity struct{ env Env }

// Name implements Step.
func (s *GuardIdentity) Name() string { return "guard-identity" }

type gitKey struct {
	key   string
	value string
}

func identity(a answers.Answers) ([]gitKey, error) {
	g := a.GitHub
	if strings.TrimSpace(g.Login) == "" {
		return nil, codes.New(codes.GuardNoIdentity, "github.login is empty; the guard needs this machine's GitHub login")
	}
	if strings.TrimSpace(g.Email) == "" {
		return nil, codes.New(codes.GuardNoIdentity, "github.email is empty; the guard needs the commit email")
	}
	name := g.Name
	if name == "" {
		name = g.Login
	}
	return []gitKey{
		{"guard.expectedLogin", g.Login},
		{"guard.expectedName", name},
		{"hooks.expectedAuthorEmail", g.Email},
		{"user.name", name},
		{"user.email", g.Email},
	}, nil
}

// globalGet reads one global git config key; unset reads as "".
func (e Env) globalGet(ctx context.Context, key string) (string, error) {
	res, err := e.run(ctx, "git", "config", "--global", "--get", key)
	if err != nil {
		if sysexec.ExitCode(err) == 1 {
			return "", nil
		}
		return "", codes.Wrap(codes.ExecFailed, err, "read git config "+key)
	}
	return strings.TrimSpace(res.Stdout), nil
}

// compare returns the keys that are unset and the keys set to something else.
func (s *GuardIdentity) compare(ctx context.Context, want []gitKey) (unset, differ []string, err error) {
	for _, k := range want {
		have, err := s.env.globalGet(ctx, k.key)
		if err != nil {
			return nil, nil, err
		}
		switch {
		case have == "":
			unset = append(unset, k.key)
		case have != k.value:
			differ = append(differ, k.key)
		}
	}
	return unset, differ, nil
}

// Check implements Step.
func (s *GuardIdentity) Check(ctx context.Context, a answers.Answers) (Status, error) {
	want, err := identity(a)
	if err != nil {
		return StatusMissing, err
	}
	unset, differ, err := s.compare(ctx, want)
	if err != nil {
		return StatusMissing, err
	}
	if len(differ) > 0 {
		return StatusDrift, driftError(differ)
	}
	if len(unset) > 0 {
		return StatusMissing, codes.New(codes.StepFailed, "not set: %s", strings.Join(unset, ", "))
	}
	return StatusOK, nil
}

func driftError(differ []string) error {
	return codes.New(codes.GuardIdentityDrift,
		"%s already set to a different identity; warren leaves it alone (pass --allow-identity-change to replace it on purpose)",
		strings.Join(differ, ", "))
}

// Apply implements Step.
func (s *GuardIdentity) Apply(ctx context.Context, a answers.Answers) (Result, error) {
	want, err := identity(a)
	if err != nil {
		return Result{}, err
	}
	unset, differ, err := s.compare(ctx, want)
	if err != nil {
		return Result{}, err
	}
	if len(differ) > 0 && !s.env.AllowIdentityChange {
		s.env.Log.Warn("guard identity drift, left alone", golog.F("keys", strings.Join(differ, ",")))
		return Result{}, driftError(differ)
	}
	if len(unset) == 0 && len(differ) == 0 {
		return Result{Message: "already set for " + a.GitHub.Login}, nil
	}
	if len(differ) > 0 {
		s.env.Log.Warn("replacing the guard identity, as allowed", golog.F("keys", strings.Join(differ, ",")))
	}
	for _, k := range want {
		if _, err := s.env.run(ctx, "git", "config", "--global", k.key, k.value); err != nil {
			return Result{}, codes.Wrap(codes.ExecFailed, err, "set git config "+k.key)
		}
	}
	s.env.Log.Info("guard identity set", golog.F("keys", len(want)))
	return Result{Changed: true, Message: "set for " + a.GitHub.Login}, nil
}

// GlobalGitConfig reads one key of the global git config; an unset key reads as "". The
// interactive init uses it to offer this machine's own identity as the default answer.
func (e Env) GlobalGitConfig(ctx context.Context, key string) (string, error) {
	return e.globalGet(ctx, key)
}
