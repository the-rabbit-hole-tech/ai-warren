package commands

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
	"bytes"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/steps"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec/sysexectest"
)

// panicPrompter fails the test on any question.
type panicPrompter struct{ t *testing.T }

func (p panicPrompter) Select(title string, _ []string, _ string) (string, error) {
	p.t.Fatalf("prompted: %s", title)
	return "", nil
}

func (p panicPrompter) Input(title, _ string) (string, error) {
	p.t.Fatalf("prompted: %s", title)
	return "", nil
}

func (p panicPrompter) Confirm(title, _ string) (bool, error) {
	p.t.Fatalf("prompted: %s", title)
	return false, nil
}

// scriptedPrompter answers questions in order and records the titles.
type scriptedPrompter struct {
	answers []string
	asked   []string
}

func (p *scriptedPrompter) next(title string) string {
	p.asked = append(p.asked, title)
	a := p.answers[0]
	p.answers = p.answers[1:]
	return a
}

func (p *scriptedPrompter) Select(title string, _ []string, _ string) (string, error) {
	return p.next(title), nil
}

func (p *scriptedPrompter) Input(title, _ string) (string, error) { return p.next(title), nil }

func (p *scriptedPrompter) Confirm(title, _ string) (bool, error) {
	return p.next(title) == "yes", nil
}

// readyMachine is a fake machine where every step for testperson is already in place.
func readyMachine(t *testing.T) (steps.Env, *sysexectest.Fake) {
	t.Helper()
	home := t.TempDir()
	fake := sysexectest.New()
	env := steps.Env{
		Exec:   fake,
		GOOS:   "linux",
		Home:   home,
		IsRoot: true,
		Getenv: func(k string) string {
			if k == "PATH" {
				return "/usr/bin:" + filepath.Join(home, "go", "bin")
			}
			return ""
		},
	}
	root := filepath.Join(home, "plugin")
	dest := filepath.Join(home, ".config", "warren", "git-hooks")
	link := filepath.Join(home, ".config", "git", "hooks")
	require.NoError(t, os.MkdirAll(dest, 0o755))
	require.NoError(t, os.WriteFile(filepath.Join(dest, "VERSION"), []byte("abc\n"), 0o600))
	require.NoError(t, os.MkdirAll(filepath.Dir(link), 0o755))
	require.NoError(t, os.Symlink(dest, link))
	require.NoError(t, os.MkdirAll(root, 0o755))

	fake.Program("tmux", "/usr/bin/tmux").Program("gh", "/usr/bin/gh").Program("claude", "/usr/bin/claude")
	fake.OnOutput("/usr/bin/claude plugin marketplace list --json", `[{"name":"ai-warren","source":"directory"}]`)
	fake.OnOutput("/usr/bin/claude plugin list --json", `[{"id":"warren@ai-warren","scope":"user","enabled":true,"installPath":"`+root+`"}]`)
	for k, v := range map[string]string{
		"guard.expectedLogin":       "testperson",
		"guard.expectedName":        "testperson",
		"hooks.expectedAuthorEmail": "1+testperson@users.noreply.github.com",
		"user.name":                 "testperson",
		"user.email":                "1+testperson@users.noreply.github.com",
		"core.hooksPath":            link,
	} {
		fake.OnOutput("git config --global --get "+k, v+"\n")
	}
	fake.OnExit(filepath.Join(root, "bin", "warren-guard-sync")+" --quiet", 0)
	return env, fake
}

func execute(t *testing.T, args []string, stdin string, opts ...Option) (string, string, error) {
	t.Helper()
	root := RootCmd(opts...)
	var out, errOut bytes.Buffer
	root.SetArgs(args)
	root.SetOut(&out)
	root.SetErr(&errOut)
	root.SetIn(strings.NewReader(stdin))
	root.SilenceErrors = true
	err := root.Execute()
	return out.String(), errOut.String(), err
}

func exampleConfig() string {
	return filepath.Join("..", "..", "test", "container", "agent-machine.yaml")
}
