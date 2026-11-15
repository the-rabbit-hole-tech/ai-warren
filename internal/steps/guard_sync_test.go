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
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec/sysexectest"
)

// syncFixture sets up a fake installed plugin and a fake warren-guard-sync that behaves like the
// real script: it writes the copy and its VERSION, then exits 1 while the link or core.hooksPath
// is wrong, 3 after a fresh copy, 0 when in sync, and 4 when older is set and a copy is there
// (the plugin is older than the copy's, so the copy is kept).
type syncFixture struct {
	env   Env
	fake  *sysexectest.Fake
	root  string
	link  string
	dest  string
	hp    *string
	older bool
}

func newSyncFixture(t *testing.T, hooksPath string) *syncFixture {
	t.Helper()
	env, fake := testEnv(t, "linux")
	f := &syncFixture{
		env:  env,
		fake: fake,
		root: filepath.Join(env.Home, "plugin", "warren"),
		link: filepath.Join(env.Home, ".config", "git", "hooks"),
		dest: filepath.Join(env.Home, ".config", "warren", "git-hooks"),
		hp:   &hooksPath,
	}
	require.NoError(t, os.MkdirAll(filepath.Join(f.root, "bin"), 0o755))
	fake.Program("claude", "/usr/bin/claude")
	fake.OnOutput("/usr/bin/claude plugin list --json",
		`[{"id":"warren@ai-warren","scope":"user","enabled":true,"installPath":"`+f.root+`"}]`)

	fake.On("git config --global --get core.hooksPath", func(sysexec.Command, string) (sysexec.Result, error) {
		if *f.hp == "" {
			return sysexec.Result{ExitCode: 1}, &sysexec.ExitError{Command: "git", Code: 1}
		}
		return sysexec.Result{Stdout: *f.hp + "\n"}, nil
	})
	fake.On("git config --global core.hooksPath "+f.link, func(sysexec.Command, string) (sysexec.Result, error) {
		*f.hp = f.link
		return sysexec.Result{}, nil
	})
	script := filepath.Join(f.root, "bin", "warren-guard-sync")
	fake.On(script+" --quiet", func(c sysexec.Command, _ string) (sysexec.Result, error) {
		assert.Contains(t, c.Env, "CLAUDE_PLUGIN_ROOT="+f.root)
		code := 0
		if _, err := os.Stat(filepath.Join(f.dest, "VERSION")); err == nil && f.older {
			code = 4
		} else if err != nil {
			require.NoError(t, os.MkdirAll(f.dest, 0o755))
			require.NoError(t, os.WriteFile(filepath.Join(f.dest, "VERSION"), []byte("abc\n"), 0o600))
			code = 3
		}
		target, err := os.Readlink(f.link)
		if err != nil || target != f.dest || *f.hp != f.link {
			code = 1
		}
		if code == 0 {
			return sysexec.Result{}, nil
		}
		return sysexec.Result{ExitCode: code}, &sysexec.ExitError{Command: script, Code: code}
	})
	return f
}

func TestGuardSyncFreshMachine(t *testing.T) {
	ctx := context.Background()
	f := newSyncFixture(t, "")
	step := &GuardSync{env: f.env}

	st, _ := step.Check(ctx, testAnswers())
	assert.Equal(t, StatusMissing, st)

	res, err := step.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.True(t, res.Changed)

	target, err := os.Readlink(f.link)
	require.NoError(t, err)
	assert.Equal(t, f.dest, target)
	assert.Equal(t, f.link, *f.hp)

	st, err = step.Check(ctx, testAnswers())
	require.NoError(t, err)
	assert.Equal(t, StatusOK, st)

	res, err = step.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.False(t, res.Changed)
}

func TestGuardSyncOlderPluginKeepsTheCopy(t *testing.T) {
	ctx := context.Background()
	f := newSyncFixture(t, "")
	step := &GuardSync{env: f.env}
	_, err := step.Apply(ctx, testAnswers())
	require.NoError(t, err)

	f.older = true
	res, err := step.Apply(ctx, testAnswers())
	require.NoError(t, err, "an older plugin keeping the newer copy is not a failure")
	assert.False(t, res.Changed)
	assert.Contains(t, res.Message, "older")
}

func TestGuardSyncHooksPathElsewhereIsDrift(t *testing.T) {
	ctx := context.Background()
	f := newSyncFixture(t, "/somewhere/else")
	step := &GuardSync{env: f.env}

	st, err := step.Check(ctx, testAnswers())
	assert.Equal(t, StatusDrift, st)
	assert.True(t, codes.Is(err, codes.GuardSyncDrift))

	_, err = step.Apply(ctx, testAnswers())
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.GuardSyncDrift))
	for _, c := range f.fake.Calls() {
		assert.False(t, strings.HasPrefix(c, "git config --global core.hooksPath"), "never changes core.hooksPath: %s", c)
	}
	_, err = os.Lstat(f.link)
	assert.True(t, os.IsNotExist(err), "never makes the link")
}

func TestGuardSyncLinkElsewhereIsDrift(t *testing.T) {
	ctx := context.Background()
	f := newSyncFixture(t, "")
	require.NoError(t, os.MkdirAll(filepath.Dir(f.link), 0o755))
	require.NoError(t, os.Symlink("/elsewhere/hooks", f.link))
	step := &GuardSync{env: f.env}

	st, _ := step.Check(ctx, testAnswers())
	assert.Equal(t, StatusDrift, st)
	_, err := step.Apply(ctx, testAnswers())
	assert.True(t, codes.Is(err, codes.GuardSyncDrift))
	target, _ := os.Readlink(f.link)
	assert.Equal(t, "/elsewhere/hooks", target)
	assert.Equal(t, "", *f.hp)
}

func TestGuardSyncPrefersReadFromFolder(t *testing.T) {
	f := newSyncFixture(t, "")
	folder := filepath.Join(f.env.Home, "marketplace", "plugins", "warren")
	require.NoError(t, os.MkdirAll(folder, 0o755))
	f.fake.OnOutput("/usr/bin/claude plugin list --json",
		`[{"id":"warren@ai-warren","scope":"user","installPath":"`+f.root+`","readFromFolder":"`+folder+`"}]`)
	root, err := (&GuardSync{env: f.env}).pluginRoot(context.Background(), testAnswers())
	require.NoError(t, err)
	assert.Equal(t, folder, root)
}

func TestGuardSyncPluginNotInstalled(t *testing.T) {
	f := newSyncFixture(t, "")
	f.fake.OnOutput("/usr/bin/claude plugin list --json", "[]")
	_, err := (&GuardSync{env: f.env}).Apply(context.Background(), testAnswers())
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.PluginRootNotFound))
}
