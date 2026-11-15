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
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

func TestToolsStepInstallsMissing(t *testing.T) {
	ctx := context.Background()

	t.Run("darwin uses brew", func(t *testing.T) {
		env, fake := testEnv(t, "darwin")
		fake.Program("brew", "/opt/homebrew/bin/brew").Program("gh", "/opt/homebrew/bin/gh").Program("claude", "/usr/local/bin/claude")
		fake.On("brew install tmux", installs(fake, "tmux", "/opt/homebrew/bin/tmux"))
		step := &Tools{env: env}

		st, err := step.Check(ctx, testAnswers())
		assert.Equal(t, StatusMissing, st)
		assert.Error(t, err)

		res, err := step.Apply(ctx, testAnswers())
		require.NoError(t, err)
		assert.True(t, res.Changed)
		assert.Equal(t, []string{"brew install tmux"}, fake.Calls())
		assert.Contains(t, res.Message, "tmux")

		st, err = step.Check(ctx, testAnswers())
		require.NoError(t, err)
		assert.Equal(t, StatusOK, st)
	})

	t.Run("linux as root uses apt-get", func(t *testing.T) {
		env, fake := testEnv(t, "linux")
		fake.Program("apt-get", "/usr/bin/apt-get").Program("gh", "/usr/bin/gh").Program("claude", "/usr/bin/claude")
		fake.OnExit("apt-get update", 0)
		fake.On("apt-get install -y tmux", installs(fake, "tmux", "/usr/bin/tmux"))
		step := &Tools{env: env}

		res, err := step.Apply(ctx, testAnswers())
		require.NoError(t, err)
		assert.True(t, res.Changed)
		assert.Equal(t, []string{"apt-get update", "apt-get install -y tmux"}, fake.Calls())
		for _, c := range fake.Commands() {
			assert.Contains(t, c.Env, "DEBIAN_FRONTEND=noninteractive")
		}
	})

	t.Run("linux as a user goes through sudo", func(t *testing.T) {
		env, fake := testEnv(t, "linux")
		env.IsRoot = false
		fake.Program("apt-get", "/usr/bin/apt-get").Program("sudo", "/usr/bin/sudo").Program("claude", "/usr/bin/claude")
		fake.OnExit("sudo apt-get update", 0)
		fake.On("sudo apt-get install -y tmux", installs(fake, "tmux", "/usr/bin/tmux"))
		fake.On("sudo apt-get install -y gh", installs(fake, "gh", "/usr/bin/gh"))
		step := &Tools{env: env}

		_, err := step.Apply(ctx, testAnswers())
		require.NoError(t, err)
		assert.Equal(t, []string{"sudo apt-get update", "sudo apt-get install -y tmux", "sudo apt-get install -y gh"}, fake.Calls())
	})

	t.Run("claude comes from the official installer", func(t *testing.T) {
		env, fake := testEnv(t, "linux")
		fake.Program("tmux", "/usr/bin/tmux").Program("gh", "/usr/bin/gh").Program("bash", "/bin/bash").Program("curl", "/usr/bin/curl")
		local := filepath.Join(env.Home, ".local", "bin", "claude")
		fake.On("bash -c curl -fsSL https://claude.ai/install.sh | bash", installs(fake, local, local))
		step := &Tools{env: env}

		res, err := step.Apply(ctx, testAnswers())
		require.NoError(t, err)
		assert.True(t, res.Changed)
		assert.Equal(t, []string{"bash -c curl -fsSL https://claude.ai/install.sh | bash"}, fake.Calls())

		st, err := step.Check(ctx, testAnswers())
		require.NoError(t, err)
		assert.Equal(t, StatusOK, st, "claude in ~/.local/bin counts as installed")
	})

	t.Run("nothing missing changes nothing", func(t *testing.T) {
		env, fake := testEnv(t, "darwin")
		fake.Program("tmux", "/x/tmux").Program("gh", "/x/gh").Program("claude", "/x/claude")
		res, err := (&Tools{env: env}).Apply(ctx, testAnswers())
		require.NoError(t, err)
		assert.False(t, res.Changed)
		assert.Empty(t, fake.Calls())
	})

	t.Run("darwin without brew fails", func(t *testing.T) {
		env, fake := testEnv(t, "darwin")
		fake.Program("gh", "/x/gh").Program("claude", "/x/claude")
		_, err := (&Tools{env: env}).Apply(ctx, testAnswers())
		require.Error(t, err)
		assert.True(t, codes.Is(err, codes.ToolsNoPackager))
		assert.Empty(t, fake.Calls())
	})
}
