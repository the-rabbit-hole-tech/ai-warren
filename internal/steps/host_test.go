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
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

func hostAnswers(t *testing.T, path string) answers.Answers {
	t.Helper()
	a := testAnswers()
	a.Host = answers.HostAnswers{
		Path:           path,
		Name:           "testbox",
		OS:             "Linux",
		Shell:          "bash",
		Timezone:       "UTC",
		CodeRoot:       "/opt/example/Code",
		CredentialsDir: "/opt/example/keys",
		GitHost:        "github.com",
		GitAccount:     "testperson",
		GitName:        "testperson",
		GitEmail:       "1+testperson@users.noreply.github.com",
		CLIs:           []string{"gh", "go"},
		OpsSession:     "OPS",
		CodingSession:  "CODING",
		Windows:        []string{"APP (/opt/example/Code/app)"},
		ReviewWindows:  []string{"07:00", "18:00"},
		WorkingHours:   "9:00 to 17:00 UTC, Monday to Friday",
		SetupDir:       "/opt/example/setup",
		OwnerQueue:     "/opt/example/setup/queue.md",
		BugLogs:        "/opt/example/setup/bugs",
		Holding:        "/opt/example/setup/holding",
		LaneScratch:    "/tmp/lane",
		LessonsLog:     "/opt/example/lessons.md",
	}
	return a
}

func TestHostTemplateCopyMatchesHub(t *testing.T) {
	hub, err := os.ReadFile(filepath.Join("..", "..", "hosts", "_template", "CLAUDE.host.md"))
	require.NoError(t, err)
	assert.Equal(t, string(hub), hostTemplate, "internal/steps/templates/CLAUDE.host.md.tmpl must equal hosts/_template/CLAUDE.host.md")
}

func TestHostStepMissingThenOKThenDrift(t *testing.T) {
	ctx := context.Background()
	env, _ := testEnv(t, "linux")
	path := filepath.Join(env.Home, ".claude", "CLAUDE.host.md")
	a := hostAnswers(t, path)
	step := &Host{env: env}

	st, err := step.Check(ctx, a)
	assert.Equal(t, StatusMissing, st)
	assert.Error(t, err)

	res, err := step.Apply(ctx, a)
	require.NoError(t, err)
	assert.True(t, res.Changed)
	body, err := os.ReadFile(path)
	require.NoError(t, err)
	assert.Contains(t, string(body), "# Host rules: testbox")
	assert.Contains(t, string(body), "export WARREN_OPS_SESSION=OPS")
	assert.Contains(t, string(body), "gh, go")
	assert.NotContains(t, string(body), "{{")

	st, err = step.Check(ctx, a)
	require.NoError(t, err)
	assert.Equal(t, StatusOK, st)
	res, err = step.Apply(ctx, a)
	require.NoError(t, err)
	assert.False(t, res.Changed)

	require.NoError(t, os.WriteFile(path, []byte("my own edits\n"), 0o600))
	st, err = step.Check(ctx, a)
	assert.Equal(t, StatusDrift, st)
	assert.Error(t, err)
	res, err = step.Apply(ctx, a)
	require.NoError(t, err)
	assert.False(t, res.Changed)
	assert.Contains(t, res.Message, "differs")
	body, _ = os.ReadFile(path)
	assert.Equal(t, "my own edits\n", string(body), "drift never overwrites")
}

func TestHostStepDefaultPathAndNoOtherWrites(t *testing.T) {
	ctx := context.Background()
	env, _ := testEnv(t, "linux")
	a := hostAnswers(t, "")
	_, err := (&Host{env: env}).Apply(ctx, a)
	require.NoError(t, err)
	var files []string
	require.NoError(t, filepath.Walk(env.Home, func(p string, info os.FileInfo, err error) error {
		if err == nil && !info.IsDir() {
			files = append(files, p)
		}
		return err
	}))
	assert.Equal(t, []string{filepath.Join(env.Home, ".claude", "CLAUDE.host.md")}, files)
}

func TestHostStepOptionalSectionsLeftOut(t *testing.T) {
	env, _ := testEnv(t, "linux")
	path := filepath.Join(t.TempDir(), "h.md")
	a := hostAnswers(t, path)
	_, err := (&Host{env: env}).Apply(context.Background(), a)
	require.NoError(t, err)
	body, _ := os.ReadFile(path)
	assert.NotContains(t, string(body), "Hand-off site")
	assert.NotContains(t, string(body), "Session hooks")
	assert.NotContains(t, string(body), "## Notes")
	assert.NotContains(t, string(body), "## Lessons")

	a.Host.HandoffSite = "/opt/example/handoff"
	a.Host.HandoffPort = 8080
	a.Host.Hooks = []string{"statusline.sh"}
	path2 := filepath.Join(t.TempDir(), "h2.md")
	a.Host.Path = path2
	_, err = (&Host{env: env}).Apply(context.Background(), a)
	require.NoError(t, err)
	body, _ = os.ReadFile(path2)
	assert.Contains(t, string(body), "http://127.0.0.1:8080/")
	assert.Contains(t, string(body), "statusline.sh")
}

func TestHostStepSkippedWithoutHostAnswers(t *testing.T) {
	env, _ := testEnv(t, "linux")
	st, err := (&Host{env: env}).Check(context.Background(), testAnswers())
	require.NoError(t, err)
	assert.Equal(t, StatusSkipped, st)
	res, err := (&Host{env: env}).Apply(context.Background(), testAnswers())
	require.NoError(t, err)
	assert.False(t, res.Changed)
}

func TestHostStepNeedsCoreValues(t *testing.T) {
	env, _ := testEnv(t, "linux")
	a := hostAnswers(t, filepath.Join(t.TempDir(), "h.md"))
	a.Host.GitEmail = ""
	_, err := (&Host{env: env}).Apply(context.Background(), a)
	require.Error(t, err)
	assert.True(t, codes.Is(err, codes.ConfigInvalid))
	assert.True(t, strings.Contains(err.Error(), "git_email"))
}
