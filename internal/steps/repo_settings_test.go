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
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec/sysexectest"
)

// repoFixture makes a folder standing in for a repo and fakes the commands the step runs there.
type repoFixture struct {
	dir       string
	installed map[string]string // plugin id -> scope, for this repo
	ignored   bool              // what git check-ignore answers for settings.local.json
	installs  []sysexec.Command
}

func newRepoFixture(t *testing.T, fake *sysexectest.Fake) *repoFixture {
	t.Helper()
	f := &repoFixture{dir: t.TempDir(), installed: map[string]string{}}
	fake.Program("claude", "/usr/bin/claude")
	fake.Program("git", "/usr/bin/git")
	fake.On("/usr/bin/claude plugin list --json", func(sysexec.Command, string) (sysexec.Result, error) {
		list := []map[string]any{{"id": "warren@ai-warren", "version": "0.2.0", "scope": "project", "enabled": true, "projectPath": "/somewhere/else"}}
		for id, scope := range f.installed {
			list = append(list, map[string]any{"id": id, "version": "0.2.0", "scope": scope, "enabled": true, "projectPath": f.dir})
		}
		out, _ := json.Marshal(list)
		return sysexec.Result{Stdout: string(out)}, nil
	})
	for _, id := range []string{"warren@ai-warren", "github@ai-warren", "coding@ai-warren"} {
		for _, scope := range []string{"project", "local"} {
			fake.On("/usr/bin/claude plugin install "+id+" --scope "+scope+" --json", func(c sysexec.Command, _ string) (sysexec.Result, error) {
				f.installs = append(f.installs, c)
				f.installed[c.Args[2]] = c.Args[4]
				return sysexec.Result{Stdout: `{"outcome":"ok"}`}, nil
			})
		}
	}
	fake.On("git -C "+f.dir+" check-ignore -q .claude/settings.local.json", func(sysexec.Command, string) (sysexec.Result, error) {
		if f.ignored {
			return sysexec.Result{}, nil
		}
		return sysexec.Result{ExitCode: 1}, &sysexec.ExitError{Command: "git check-ignore", Code: 1}
	})
	fake.OnOutput("git -C "+f.dir+" rev-parse --git-path info/exclude", ".git/info/exclude\n")
	return f
}

func repoAnswers(dir, visibility string) answers.Answers {
	a := testAnswers()
	a.Repo = answers.RepoAnswers{Dir: dir, Visibility: visibility, Plugins: []string{"github@ai-warren", "coding@ai-warren"}}
	return a
}

func readJSON(t *testing.T, path string) map[string]any {
	t.Helper()
	body, err := os.ReadFile(path) // #nosec G304 -- a test fixture
	require.NoError(t, err)
	var m map[string]any
	require.NoError(t, json.Unmarshal(body, &m))
	return m
}

func TestRepoSettingsSkippedWithoutARepo(t *testing.T) {
	env, _ := testEnv(t, "linux")
	st, err := (&RepoSettings{env: env}).Check(context.Background(), testAnswers())
	require.NoError(t, err)
	assert.Equal(t, StatusSkipped, st)
}

func TestRepoSettingsWritesPrivateRepoSettings(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	f := newRepoFixture(t, fake)
	s := &RepoSettings{env: env}
	a := repoAnswers(f.dir, "private")

	st, err := s.Check(ctx, a)
	assert.Equal(t, StatusMissing, st)
	assert.True(t, codes.Is(err, codes.RepoNotSetUp))

	res, err := s.Apply(ctx, a)
	require.NoError(t, err)
	assert.True(t, res.Changed)

	m := readJSON(t, filepath.Join(f.dir, ".claude", "settings.json"))
	assert.Equal(t, map[string]any{"ai-warren": map[string]any{"source": map[string]any{"source": "github", "repo": "the-rabbit-hole-tech/ai-warren"}}}, m["extraKnownMarketplaces"])
	assert.Equal(t, map[string]any{"warren@ai-warren": true, "github@ai-warren": true, "coding@ai-warren": true}, m["enabledPlugins"])
	assert.NoFileExists(t, filepath.Join(f.dir, ".claude", "settings.local.json"))
	require.Len(t, f.installs, 3)
	for _, c := range f.installs {
		assert.Equal(t, f.dir, c.Dir, "installs run in the repo")
		assert.Equal(t, "project", c.Args[4])
	}

	st, err = s.Check(ctx, a)
	require.NoError(t, err)
	assert.Equal(t, StatusOK, st)
	res, err = s.Apply(ctx, a)
	require.NoError(t, err)
	assert.False(t, res.Changed, "a second run changes nothing")
	assert.Len(t, f.installs, 3)
}

func TestRepoSettingsKeepsExistingKeysAndOrder(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	f := newRepoFixture(t, fake)
	require.NoError(t, os.MkdirAll(filepath.Join(f.dir, ".claude"), 0o750))
	existing := "{\n    \"permissions\": {\"allow\": [\"Bash(go test:*)\"]},\n    \"hooks\": {},\n    \"enabledPlugins\": {\"other@elsewhere\": true}\n}\n"
	path := filepath.Join(f.dir, ".claude", "settings.json")
	require.NoError(t, os.WriteFile(path, []byte(existing), 0o600))

	_, err := (&RepoSettings{env: env}).Apply(ctx, repoAnswers(f.dir, "private"))
	require.NoError(t, err)

	body, err := os.ReadFile(path) // #nosec G304 -- a test fixture
	require.NoError(t, err)
	text := string(body)
	assert.Less(t, strings.Index(text, `"permissions"`), strings.Index(text, `"hooks"`), "existing keys keep their order")
	assert.Less(t, strings.Index(text, `"hooks"`), strings.Index(text, `"enabledPlugins"`))
	assert.Less(t, strings.Index(text, `"enabledPlugins"`), strings.Index(text, `"extraKnownMarketplaces"`), "new keys go last")
	assert.Contains(t, text, `"permissions": {"allow": ["Bash(go test:*)"]},`, "untouched values are written back exactly as they were")
	assert.Contains(t, text, `"hooks": {},`)
	m := readJSON(t, path)
	assert.Equal(t, map[string]any{"allow": []any{"Bash(go test:*)"}}, m["permissions"])
	assert.Equal(t, true, m["enabledPlugins"].(map[string]any)["other@elsewhere"])
	assert.Equal(t, true, m["enabledPlugins"].(map[string]any)["github@ai-warren"])
}

func TestRepoSettingsPublicRepoStaysLocal(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	f := newRepoFixture(t, fake)
	require.NoError(t, os.MkdirAll(filepath.Join(f.dir, ".git", "info"), 0o750))

	_, err := (&RepoSettings{env: env}).Apply(ctx, repoAnswers(f.dir, "public"))
	require.NoError(t, err)

	assert.NoFileExists(t, filepath.Join(f.dir, ".claude", "settings.json"), "a public repo never gets a committed settings file")
	m := readJSON(t, filepath.Join(f.dir, ".claude", "settings.local.json"))
	assert.Contains(t, m, "enabledPlugins")
	for _, c := range f.installs {
		assert.Equal(t, "local", c.Args[4])
	}
	exclude, err := os.ReadFile(filepath.Join(f.dir, ".git", "info", "exclude")) // #nosec G304 -- a test fixture
	require.NoError(t, err)
	assert.Contains(t, string(exclude), ".claude/settings.local.json", "kept out of git locally when nothing ignores it")
}

func TestRepoSettingsLeavesAnotherMarketplaceSourceAlone(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	f := newRepoFixture(t, fake)
	require.NoError(t, os.MkdirAll(filepath.Join(f.dir, ".claude"), 0o750))
	path := filepath.Join(f.dir, ".claude", "settings.json")
	before := `{"extraKnownMarketplaces": {"ai-warren": {"source": {"source": "directory", "path": "/tmp/x"}}}}`
	require.NoError(t, os.WriteFile(path, []byte(before), 0o600))

	s := &RepoSettings{env: env}
	st, err := s.Check(ctx, repoAnswers(f.dir, "private"))
	assert.Equal(t, StatusDrift, st)
	assert.True(t, codes.Is(err, codes.RepoSettingsDrift))
	_, err = s.Apply(ctx, repoAnswers(f.dir, "private"))
	assert.True(t, codes.Is(err, codes.RepoSettingsDrift))
	after, _ := os.ReadFile(path) // #nosec G304 -- a test fixture
	assert.Equal(t, before, string(after), "drift is reported, never overwritten")
	assert.Empty(t, f.installs)
}

func TestRepoSettingsRejectsBadAnswers(t *testing.T) {
	env, fake := testEnv(t, "linux")
	f := newRepoFixture(t, fake)
	s := &RepoSettings{env: env}
	foreign := repoAnswers(f.dir, "private")
	foreign.Repo.Plugins = []string{"x@elsewhere"}
	for name, a := range map[string]answers.Answers{
		"no visibility":  repoAnswers(f.dir, ""),
		"odd visibility": repoAnswers(f.dir, "secret-ish"),
		"not a folder":   repoAnswers(filepath.Join(f.dir, "nope"), "private"),
		"foreign plugin": foreign,
	} {
		_, err := s.Apply(context.Background(), a)
		assert.True(t, codes.Is(err, codes.RepoInvalid), name)
	}
}

func TestRepoSettingsUsesTheMarketplaceSourceFromTheEnvironment(t *testing.T) {
	ctx := context.Background()
	env, fake := testEnv(t, "linux")
	env.MarketplaceSource = "someone/ai-warren-fork"
	f := newRepoFixture(t, fake)
	s := &RepoSettings{env: env}
	a := repoAnswers(f.dir, "private")

	_, err := s.Apply(ctx, a)
	require.NoError(t, err)
	m := readJSON(t, filepath.Join(f.dir, ".claude", "settings.json"))
	assert.Equal(t, map[string]any{"ai-warren": map[string]any{"source": map[string]any{"source": "github", "repo": "someone/ai-warren-fork"}}}, m["extraKnownMarketplaces"], "--marketplace-source reaches the declared marketplace")

	st, err := s.Check(ctx, a)
	require.NoError(t, err)
	assert.Equal(t, StatusOK, st)
}

func TestMarketplaceDeclFollowsTheSourceKind(t *testing.T) {
	assert.Equal(t, map[string]any{"source": map[string]any{"source": "github", "repo": "a/b"}}, marketplaceDecl("a/b"))
	assert.Equal(t, map[string]any{"source": map[string]any{"source": "git", "url": "https://example.invalid/a/b.git"}}, marketplaceDecl("https://example.invalid/a/b.git"))
	assert.Equal(t, map[string]any{"source": map[string]any{"source": "directory", "path": "/srv/market"}}, marketplaceDecl("/srv/market"))
}
