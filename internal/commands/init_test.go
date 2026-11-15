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
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

func TestInitUnattendedNoPrompts(t *testing.T) {
	env, _ := readyMachine(t)
	out, _, err := execute(t, []string{"init", "--config", exampleConfig()}, "",
		WithEnv(env), WithPrompter(panicPrompter{t}))
	require.NoError(t, err)
	for _, name := range []string{"tools", "marketplace", "plugins", "guard-identity", "guard-sync", "path"} {
		assert.Regexp(t, `(?m)^`+name+`\s+ok`, out)
	}
	assert.Regexp(t, `(?m)^gh-auth\s+skipped\s+skipped: no token`, out)
	assert.Regexp(t, `(?m)^lessons-log\s+changed\s+created `, out)

	saved, err := answers.FromJSONFile(filepath.Join(env.Home, ".config", "warren", "answers.json"))
	require.NoError(t, err)
	assert.Equal(t, "testperson", saved.GitHub.Login)
}

func TestInitRejectsSecretConfig(t *testing.T) {
	env, fake := readyMachine(t)
	cfg := filepath.Join(t.TempDir(), "a.yaml")
	require.NoError(t, os.WriteFile(cfg, []byte("version: 1\nrole: ops\ngithub:\n  login: x\n  token: ghp_x\n"), 0o600))
	_, _, err := execute(t, []string{"init", "--config", cfg}, "", WithEnv(env), WithPrompter(panicPrompter{t}))
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.ConfigSecret))
	assert.Empty(t, fake.Calls(), "nothing runs when the answers are rejected")
}

func TestInitDryRunChangesNothing(t *testing.T) {
	env, fake := readyMachine(t)
	fake.Remove("tmux")
	out, _, err := execute(t, []string{"init", "--config", exampleConfig(), "--dry-run"}, "", WithEnv(env), WithPrompter(panicPrompter{t}))
	require.NoError(t, err)
	assert.Regexp(t, `(?m)^tools\s+missing\s+would apply`, out)
	assert.False(t, fake.Ran("apt-get"))
	_, err = os.Stat(filepath.Join(env.Home, ".config", "warren", "answers.json"))
	assert.True(t, os.IsNotExist(err))
}

func TestInitOnlyGroup(t *testing.T) {
	env, _ := readyMachine(t)
	out, _, err := execute(t, []string{"init", "-c", exampleConfig(), "--only", "github"}, "", WithEnv(env), WithPrompter(panicPrompter{t}))
	require.NoError(t, err)
	assert.Regexp(t, `(?m)^gh-auth`, out)
	assert.NotRegexp(t, `(?m)^tools`, out)

	_, _, err = execute(t, []string{"init", "-c", exampleConfig(), "--only", "everything"}, "", WithEnv(env))
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.Usage))
}

func TestInitStopsAtFirstFailure(t *testing.T) {
	env, fake := readyMachine(t)
	fake.OnOutput("git config --global --get guard.expectedLogin", "someoneelse\n")
	out, _, err := execute(t, []string{"init", "-c", exampleConfig()}, "", WithEnv(env), WithPrompter(panicPrompter{t}))
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.GuardIdentityDrift))
	assert.NotRegexp(t, `(?m)^guard-sync`, out, "steps after a failure do not run")
}

func TestInitInteractive(t *testing.T) {
	env, _ := readyMachine(t)
	p := &scriptedPrompter{answers: []string{"ops", "", "testperson", "testperson", "1+testperson@users.noreply.github.com", "yes"}}
	out, _, err := execute(t, []string{"init", "--only", "machine"}, "", WithEnv(env), WithPrompter(p))
	require.NoError(t, err)
	require.Len(t, p.asked, 6, "one question at a time: role, org plugins, login, name, email, confirm")
	assert.Contains(t, p.asked[0], "role")
	assert.Regexp(t, `(?m)^guard-identity\s+ok`, out)
}

func TestInitInteractiveDeclined(t *testing.T) {
	env, fake := readyMachine(t)
	p := &scriptedPrompter{answers: []string{"ops", "", "testperson", "testperson", "1+testperson@users.noreply.github.com", "no"}}
	_, _, err := execute(t, []string{"init"}, "", WithEnv(env), WithPrompter(p))
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.PromptCancelled))
	assert.False(t, fake.Ran("/usr/bin/claude"))
}

func TestDoctorJSON(t *testing.T) {
	env, fake := readyMachine(t)
	_, _, err := execute(t, []string{"init", "-c", exampleConfig()}, "", WithEnv(env), WithPrompter(panicPrompter{t}))
	require.NoError(t, err)

	out, _, err := execute(t, []string{"doctor", "--json"}, "", WithEnv(env))
	require.NoError(t, err)
	var report doctorReport
	require.NoError(t, json.Unmarshal([]byte(out), &report))
	assert.True(t, report.OK)
	got := map[string]string{}
	for _, s := range report.Steps {
		got[s.Step] = s.Status
	}
	assert.Equal(t, map[string]string{
		"tools": "ok", "marketplace": "ok", "plugins": "ok", "guard-identity": "ok",
		"guard-sync": "ok", "gh-auth": "skipped", "path": "ok", "lessons-log": "ok", "host": "skipped",
	}, got)

	fake.Remove("tmux")
	out, _, err = execute(t, []string{"doctor", "--json"}, "", WithEnv(env))
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.NotReady))
	require.NoError(t, json.Unmarshal([]byte(out), &report))
	assert.False(t, report.OK)
}

func TestDoctorWithoutSavedAnswers(t *testing.T) {
	env, _ := readyMachine(t)
	out, _, err := execute(t, []string{"doctor"}, "", WithEnv(env))
	require.Error(t, err, "no saved answers means the guard identity cannot be checked")
	assert.Regexp(t, `(?m)^guard-identity\s+missing`, out)
}

func TestStepJSON(t *testing.T) {
	env, _ := readyMachine(t)
	in := `{"version":1,"role":"ops","github":{"login":"testperson","name":"testperson","email":"1+testperson@users.noreply.github.com"}}`
	out, _, err := execute(t, []string{"step", "guard-identity", "--answers", "-"}, in, WithEnv(env))
	require.NoError(t, err)
	var res stepReport
	require.NoError(t, json.Unmarshal([]byte(out), &res))
	assert.Equal(t, stepReport{Step: "guard-identity", Status: "ok", Changed: false, Message: "already set for testperson"}, res)

	out, _, err = execute(t, []string{"step", "tools", "--answers", "-", "--check"}, in, WithEnv(env))
	require.NoError(t, err)
	require.NoError(t, json.Unmarshal([]byte(out), &res))
	assert.Equal(t, "ok", res.Status)
}

func TestStepErrors(t *testing.T) {
	env, _ := readyMachine(t)
	_, _, err := execute(t, []string{"step", "nope", "--answers", "-"}, `{"version":1}`, WithEnv(env))
	assert.True(t, codes.Is(err, codes.StepUnknown))

	out, _, err := execute(t, []string{"step", "guard-identity", "--answers", "-"}, `{"version":1,"role":"ops"}`, WithEnv(env))
	require.Error(t, err)
	var res stepReport
	require.NoError(t, json.Unmarshal([]byte(out), &res))
	assert.Equal(t, "WARREN-GUARD-NO-IDENTITY", res.Code)

	_, _, err = execute(t, []string{"step", "tools"}, "", WithEnv(env))
	assert.True(t, codes.Is(err, codes.Usage), "--answers is required")
}
