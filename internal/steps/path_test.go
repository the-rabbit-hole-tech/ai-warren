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
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestPathStepAppendsOnce(t *testing.T) {
	for goos, rc := range map[string]string{"darwin": ".zshrc", "linux": ".bashrc"} {
		t.Run(goos, func(t *testing.T) {
			ctx := context.Background()
			env, _ := testEnv(t, goos)
			env.Getenv = func(k string) string {
				if k == "PATH" {
					return "/usr/bin:/bin"
				}
				return ""
			}
			rcPath := filepath.Join(env.Home, rc)
			require.NoError(t, os.WriteFile(rcPath, []byte("alias ll='ls -l'"), 0o600))
			step := &Path{env: env}

			st, _ := step.Check(ctx, testAnswers())
			assert.Equal(t, StatusMissing, st)

			res, err := step.Apply(ctx, testAnswers())
			require.NoError(t, err)
			assert.True(t, res.Changed)

			res, err = step.Apply(ctx, testAnswers())
			require.NoError(t, err)
			assert.False(t, res.Changed)

			body, err := os.ReadFile(rcPath)
			require.NoError(t, err)
			assert.True(t, strings.HasPrefix(string(body), "alias ll='ls -l'\n"), "keeps what was there")
			assert.Equal(t, 1, strings.Count(string(body), pathMarker))
			assert.Contains(t, string(body), `export PATH="$HOME/go/bin:$PATH"`)

			st, err = step.Check(ctx, testAnswers())
			require.NoError(t, err)
			assert.Equal(t, StatusOK, st)
		})
	}
}

func TestPathStepAlreadyOnPath(t *testing.T) {
	env, _ := testEnv(t, "linux")
	env.Getenv = func(k string) string {
		if k == "PATH" {
			return "/usr/bin:" + filepath.Join(env.Home, "go", "bin")
		}
		return ""
	}
	res, err := (&Path{env: env}).Apply(context.Background(), testAnswers())
	require.NoError(t, err)
	assert.False(t, res.Changed)
	_, err = os.Stat(filepath.Join(env.Home, ".bashrc"))
	assert.True(t, os.IsNotExist(err), "no rc file written when PATH already has it")
}

func TestRegistryOrderAndFind(t *testing.T) {
	env, _ := testEnv(t, "linux")
	var names []string
	for _, s := range RegistryFor(env) {
		names = append(names, s.Name())
	}
	assert.Equal(t, []string{"host", "tools", "marketplace", "plugins", "guard-identity", "guard-sync", "gh-auth", "path", "lessons-log"}, names)
	s, err := Find(RegistryFor(env), "guard-sync")
	require.NoError(t, err)
	assert.Equal(t, "guard-sync", s.Name())
	_, err = Find(RegistryFor(env), "nope")
	assert.Error(t, err)
}
