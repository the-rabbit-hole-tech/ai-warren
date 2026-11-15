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
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec/sysexectest"
)

var identityKeys = []string{"guard.expectedLogin", "guard.expectedName", "hooks.expectedAuthorEmail", "user.name", "user.email"}

// gitConfig fakes the global git config: gets read from current, sets write to it.
func gitConfig(fake *sysexectest.Fake, current map[string]string) {
	for _, k := range identityKeys {
		if v, ok := current[k]; ok {
			fake.OnOutput("git config --global --get "+k, v+"\n")
		} else {
			fake.OnExit("git config --global --get "+k, 1)
		}
	}
}

func sets(fake *sysexectest.Fake) []string {
	var out []string
	for _, c := range fake.Calls() {
		if strings.HasPrefix(c, "git config --global ") && !strings.HasPrefix(c, "git config --global --get") {
			out = append(out, c)
		}
	}
	return out
}

func TestGuardIdentityNeverCopies(t *testing.T) {
	ctx := context.Background()

	t.Run("sets only from Answers.GitHub", func(t *testing.T) {
		env, fake := testEnv(t, "linux")
		gitConfig(fake, map[string]string{})
		want := []string{
			"git config --global guard.expectedLogin testperson",
			"git config --global guard.expectedName testperson",
			"git config --global hooks.expectedAuthorEmail 1+testperson@users.noreply.github.com",
			"git config --global user.name testperson",
			"git config --global user.email 1+testperson@users.noreply.github.com",
		}
		for _, w := range want {
			fake.OnExit(w, 0)
		}
		step := &GuardIdentity{env: env}

		st, _ := step.Check(ctx, testAnswers())
		assert.Equal(t, StatusMissing, st)
		res, err := step.Apply(ctx, testAnswers())
		require.NoError(t, err)
		assert.True(t, res.Changed)
		assert.Equal(t, want, sets(fake))
	})

	t.Run("a different identity is drift and is left alone", func(t *testing.T) {
		env, fake := testEnv(t, "linux")
		gitConfig(fake, map[string]string{
			"guard.expectedLogin":       "example-user",
			"guard.expectedName":        "example-user",
			"hooks.expectedAuthorEmail": "1234567+example-user@users.noreply.github.com",
			"user.name":                 "example-user",
			"user.email":                "1234567+example-user@users.noreply.github.com",
		})
		step := &GuardIdentity{env: env}

		st, err := step.Check(ctx, testAnswers())
		assert.Equal(t, StatusDrift, st)
		assert.True(t, codes.Is(err, codes.GuardIdentityDrift))

		_, err = step.Apply(ctx, testAnswers())
		require.Error(t, err)
		assert.True(t, codes.Is(err, codes.GuardIdentityDrift))
		assert.Empty(t, sets(fake), "identity changes are never a side effect")
	})

	t.Run("a different identity changes only when allowed", func(t *testing.T) {
		env, fake := testEnv(t, "linux")
		env.AllowIdentityChange = true
		gitConfig(fake, map[string]string{"guard.expectedLogin": "someoneelse"})
		fake.OnExit("git config --global guard.expectedLogin testperson", 0)
		fake.OnExit("git config --global guard.expectedName testperson", 0)
		fake.OnExit("git config --global hooks.expectedAuthorEmail 1+testperson@users.noreply.github.com", 0)
		fake.OnExit("git config --global user.name testperson", 0)
		fake.OnExit("git config --global user.email 1+testperson@users.noreply.github.com", 0)
		res, err := (&GuardIdentity{env: env}).Apply(ctx, testAnswers())
		require.NoError(t, err)
		assert.True(t, res.Changed)
		assert.Len(t, sets(fake), 5)
	})

	t.Run("already set changes nothing", func(t *testing.T) {
		env, fake := testEnv(t, "linux")
		gitConfig(fake, map[string]string{
			"guard.expectedLogin":       "testperson",
			"guard.expectedName":        "testperson",
			"hooks.expectedAuthorEmail": "1+testperson@users.noreply.github.com",
			"user.name":                 "testperson",
			"user.email":                "1+testperson@users.noreply.github.com",
		})
		res, err := (&GuardIdentity{env: env}).Apply(ctx, testAnswers())
		require.NoError(t, err)
		assert.False(t, res.Changed)
		assert.Empty(t, sets(fake))
	})

	t.Run("an empty login fails before touching git", func(t *testing.T) {
		env, fake := testEnv(t, "linux")
		a := testAnswers()
		a.GitHub.Login = ""
		step := &GuardIdentity{env: env}

		st, err := step.Check(ctx, a)
		assert.Equal(t, StatusMissing, st)
		assert.True(t, codes.Is(err, codes.GuardNoIdentity))
		_, err = step.Apply(ctx, a)
		require.Error(t, err)
		assert.True(t, codes.Is(err, codes.GuardNoIdentity))
		assert.Equal(t, "WARREN-GUARD-NO-IDENTITY", codes.Name(err))
		assert.Empty(t, fake.Calls())
	})

	t.Run("an empty email fails too", func(t *testing.T) {
		env, _ := testEnv(t, "linux")
		a := testAnswers()
		a.GitHub.Email = ""
		_, err := (&GuardIdentity{env: env}).Apply(ctx, a)
		assert.True(t, codes.Is(err, codes.GuardNoIdentity))
	})
}
