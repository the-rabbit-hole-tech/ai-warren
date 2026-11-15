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

// GHAuth signs gh in with the token in the environment variable GitHub.TokenEnv names. The token
// goes to `gh auth login --with-token` on stdin and is never logged or put on a command line.
// With no variable named, or the variable empty, the step is skipped.
type GHAuth struct{ env Env }

// Name implements Step.
func (s *GHAuth) Name() string { return "gh-auth" }

func (s *GHAuth) token(a answers.Answers) string {
	if a.GitHub.TokenEnv == "" {
		return ""
	}
	return s.env.Getenv(a.GitHub.TokenEnv)
}

func (s *GHAuth) signedIn(ctx context.Context) (bool, error) {
	_, err := s.env.run(ctx, "gh", "auth", "status", "--hostname", "github.com")
	if err == nil {
		return true, nil
	}
	if sysexec.ExitCode(err) > 0 {
		return false, nil
	}
	return false, codes.Wrap(codes.ExecFailed, err, "gh auth status")
}

// Check implements Step.
func (s *GHAuth) Check(ctx context.Context, a answers.Answers) (Status, error) {
	if s.token(a) == "" {
		return StatusSkipped, nil
	}
	ok, err := s.signedIn(ctx)
	if err != nil {
		return StatusMissing, err
	}
	if !ok {
		return StatusMissing, codes.New(codes.StepFailed, "gh is not signed in to github.com")
	}
	return StatusOK, nil
}

// Apply implements Step.
func (s *GHAuth) Apply(ctx context.Context, a answers.Answers) (Result, error) {
	token := s.token(a)
	if token == "" {
		s.env.Log.Info("gh sign-in skipped: no token", golog.F("token_env", a.GitHub.TokenEnv))
		return Result{Message: "skipped: no token"}, nil
	}
	ok, err := s.signedIn(ctx)
	if err != nil {
		return Result{}, err
	}
	if ok {
		return Result{Message: "gh already signed in"}, nil
	}
	s.env.Log.Info("signing gh in from the environment", golog.F("token_env", a.GitHub.TokenEnv))
	_, err = s.env.Exec.Run(ctx, sysexec.Command{
		Name:  "gh",
		Args:  []string{"auth", "login", "--hostname", "github.com", "--with-token"},
		Stdin: strings.NewReader(token),
	})
	if err != nil {
		return Result{}, codes.Wrap(codes.ExecFailed, err, "gh auth login")
	}
	return Result{Changed: true, Message: "gh signed in from $" + a.GitHub.TokenEnv}, nil
}
