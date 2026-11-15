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
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

// The shape `claude plugin list --json` prints (checked against claude 2.1.318).
const listedWarren = `[
  {
    "id": "warren@ai-warren",
    "version": "0.1.0",
    "scope": "user",
    "enabled": true,
    "installPath": "/opt/x/.claude/plugins/cache/ai-warren/warren/0.1.0",
    "readFromFolder": "/test/marketplace/plugins/warren",
    "folderVersion": "0.1.0",
    "projectEnabled": false
  }
]`

func TestPluginsStepInstalls(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	fake.Program("claude", "/usr/bin/claude")
	installed := false
	fake.On("/usr/bin/claude plugin list --json", func(sysexec.Command, string) (sysexec.Result, error) {
		if installed {
			return sysexec.Result{Stdout: listedWarren}, nil
		}
		return sysexec.Result{Stdout: "[]"}, nil
	})
	fake.On("/usr/bin/claude plugin install warren@ai-warren --scope user --json", func(sysexec.Command, string) (sysexec.Result, error) {
		installed = true
		return sysexec.Result{Stdout: `{"command":"install","outcome":"ok","pluginId":"warren@ai-warren","scope":"user"}`}, nil
	})
	step := &Plugins{env: env}

	st, _ := step.Check(ctx, testAnswers())
	assert.Equal(t, StatusMissing, st)

	res, err := step.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.True(t, res.Changed)

	st, err = step.Check(ctx, testAnswers())
	require.NoError(t, err)
	assert.Equal(t, StatusOK, st)

	res, err = step.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.False(t, res.Changed)
	n := 0
	for _, c := range fake.Calls() {
		if c == "/usr/bin/claude plugin install warren@ai-warren --scope user --json" {
			n++
		}
	}
	assert.Equal(t, 1, n, "an installed plugin is never installed again")
}

func TestPluginsStepIncludesOrgPlugins(t *testing.T) {
	env, fake := testEnv(t, "linux")
	fake.Program("claude", "/usr/bin/claude")
	fake.OnOutput("/usr/bin/claude plugin list --json", listedWarren)
	fake.OnOutput("/usr/bin/claude plugin install warren-org-example@example-org --scope user --json", `{"outcome":"ok"}`)
	a := testAnswers()
	a.OrgPlugins = []string{"warren-org-example@example-org"}
	res, err := (&Plugins{env: env}).Apply(context.Background(), a)
	require.NoError(t, err)
	assert.True(t, res.Changed)
	assert.False(t, fake.Ran("/usr/bin/claude plugin install warren@ai-warren"))
}

func TestPluginsStepProjectScopeDoesNotCount(t *testing.T) {
	env, fake := testEnv(t, "linux")
	fake.Program("claude", "/usr/bin/claude")
	fake.OnOutput("/usr/bin/claude plugin list --json", `[{"id":"warren@ai-warren","scope":"project","enabled":true}]`)
	st, _ := (&Plugins{env: env}).Check(context.Background(), testAnswers())
	assert.Equal(t, StatusMissing, st)
}
