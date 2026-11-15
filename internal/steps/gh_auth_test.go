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
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

func TestGHAuthSkippedWithoutToken(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	a := testAnswers()
	a.GitHub.TokenEnv = "GH_TOKEN"
	step := &GHAuth{env: env}

	st, err := step.Check(ctx, a)
	require.NoError(t, err)
	assert.Equal(t, StatusSkipped, st)

	res, err := step.Apply(ctx, a)
	require.NoError(t, err)
	assert.False(t, res.Changed)
	assert.Equal(t, "skipped: no token", res.Message)
	assert.Empty(t, fake.Calls())
}

func TestGHAuthLogsInFromEnv(t *testing.T) {
	ctx := context.Background()
	const token = "fake-token-value-for-test"
	env, fake := testEnv(t, "linux")
	env.Getenv = func(k string) string {
		if k == "GH_TOKEN" {
			return token
		}
		return ""
	}
	fake.Program("gh", "/usr/bin/gh")
	loggedIn := false
	fake.On("gh auth status --hostname github.com", func(c sysexec.Command, _ string) (sysexec.Result, error) {
		if loggedIn {
			return sysexec.Result{}, nil
		}
		return sysexec.Result{ExitCode: 1}, &sysexec.ExitError{Command: c.String(), Code: 1}
	})
	fake.On("gh auth login --hostname github.com --with-token", func(_ sysexec.Command, stdin string) (sysexec.Result, error) {
		loggedIn = stdin == token
		return sysexec.Result{}, nil
	})
	a := testAnswers()
	a.GitHub.TokenEnv = "GH_TOKEN"
	step := &GHAuth{env: env}

	st, _ := step.Check(ctx, a)
	assert.Equal(t, StatusMissing, st)
	res, err := step.Apply(ctx, a)
	require.NoError(t, err)
	assert.True(t, res.Changed)
	assert.True(t, loggedIn, "the token goes in on stdin")
	assert.NotContains(t, res.Message, token)
	for _, c := range fake.Commands() {
		assert.False(t, strings.Contains(c.String(), token), "the token is never on a command line")
		for _, e := range c.Env {
			assert.NotContains(t, e, token)
		}
	}
}
