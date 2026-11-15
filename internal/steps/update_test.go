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
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

// writeMarketplace lays out a local marketplace copy with the given plugin versions.
func writeMarketplace(t *testing.T, root string, versions map[string]string) {
	t.Helper()
	var plugins []map[string]any
	for name, v := range versions {
		plugins = append(plugins, map[string]any{"name": name, "source": "./plugins/" + name})
		dir := filepath.Join(root, "plugins", name, ".claude-plugin")
		require.NoError(t, os.MkdirAll(dir, 0o750))
		pj, _ := json.Marshal(map[string]string{"name": name, "version": v})
		require.NoError(t, os.WriteFile(filepath.Join(dir, "plugin.json"), pj, 0o600))
	}
	mj, _ := json.Marshal(map[string]any{"name": "ai-warren", "plugins": plugins})
	require.NoError(t, os.MkdirAll(filepath.Join(root, ".claude-plugin"), 0o750))
	require.NoError(t, os.WriteFile(filepath.Join(root, ".claude-plugin", "marketplace.json"), mj, 0o600))
}

func TestUpdateRefreshesAndUpdatesWhatIsBehind(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	fake.Program("claude", "/usr/bin/claude")
	root := t.TempDir()
	writeMarketplace(t, root, map[string]string{"warren": "0.1.0", "github": "0.2.0"})
	fake.OnOutput("/usr/bin/claude plugin marketplace list --json", `[{"name":"ai-warren","source":"github","installLocation":"`+root+`"}]`)
	installed := map[string]string{"warren": "0.1.0", "github": "0.1.0"}
	fake.On("/usr/bin/claude plugin list --json", func(sysexec.Command, string) (sysexec.Result, error) {
		out, _ := json.Marshal([]map[string]any{
			{"id": "warren@ai-warren", "version": installed["warren"], "scope": "user"},
			{"id": "github@ai-warren", "version": installed["github"], "scope": "project", "projectPath": "/repo"},
			{"id": "other@elsewhere", "version": "9.9.9", "scope": "user"},
		})
		return sysexec.Result{Stdout: string(out)}, nil
	})
	refreshed := false
	fake.On("/usr/bin/claude plugin marketplace update ai-warren --json", func(sysexec.Command, string) (sysexec.Result, error) {
		writeMarketplace(t, root, map[string]string{"warren": "0.2.0", "github": "0.2.0"})
		refreshed = true
		return sysexec.Result{Stdout: `{"outcome":"ok"}`}, nil
	})
	var dirs []string
	for _, id := range []string{"warren@ai-warren --scope user", "github@ai-warren --scope project"} {
		fake.On("/usr/bin/claude plugin update "+id+" --json", func(c sysexec.Command, _ string) (sysexec.Result, error) {
			dirs = append(dirs, c.Dir)
			installed[c.Args[2][:len(c.Args[2])-len("@ai-warren")]] = "0.2.0"
			return sysexec.Result{Stdout: `{"outcome":"ok"}`}, nil
		})
	}
	s := &Update{env: env}

	st, err := s.Check(ctx, testAnswers())
	assert.Equal(t, StatusDrift, st, "github is behind the local copy before a refresh")
	assert.True(t, codes.Is(err, codes.UpdateAvailable))

	res, err := s.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.True(t, refreshed)
	assert.True(t, res.Changed)
	assert.ElementsMatch(t, []string{"", "/repo"}, dirs, "a project-scope update runs in its repo")

	st, err = s.Check(ctx, testAnswers())
	require.NoError(t, err)
	assert.Equal(t, StatusOK, st)
}

func TestUpdateNeedsTheMarketplace(t *testing.T) {
	env, fake := testEnv(t, "linux")
	fake.Program("claude", "/usr/bin/claude")
	fake.OnOutput("/usr/bin/claude plugin marketplace list --json", `[]`)
	_, err := (&Update{env: env}).Check(context.Background(), testAnswers())
	assert.True(t, codes.Is(err, codes.MarketplaceUnknown))
}

func TestOnDemandStepsStayOutOfInitAndDoctor(t *testing.T) {
	env, _ := testEnv(t, "linux")
	for _, s := range RegistryFor(env) {
		assert.NotContains(t, []string{"repo-settings", "update"}, s.Name())
	}
	for _, n := range []string{"repo-settings", "update"} {
		_, err := Find(AllFor(env), n)
		assert.NoError(t, err, n)
	}
}
