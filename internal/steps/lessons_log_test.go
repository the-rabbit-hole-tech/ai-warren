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
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLessonsLogCreatesOnce(t *testing.T) {
	ctx := context.Background()
	env, _ := testEnv(t, "linux")
	step := &LessonsLog{env: env}
	logPath := filepath.Join(env.Home, ".claude", "warren", "lessons-log.md")

	st, err := step.Check(ctx, testAnswers())
	require.Error(t, err)
	assert.Equal(t, StatusMissing, st)

	res, err := step.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.True(t, res.Changed)

	body, err := os.ReadFile(logPath)
	require.NoError(t, err)
	assert.Equal(t, lessonsLogHeader+"\n", string(body))

	require.NoError(t, os.WriteFile(logPath, []byte(lessonsLogHeader+"\n- 2026-01-02 a lesson\n"), 0o600))
	res, err = step.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.False(t, res.Changed)
	body, err = os.ReadFile(logPath)
	require.NoError(t, err)
	assert.Contains(t, string(body), "a lesson", "an existing log is left alone")

	st, err = step.Check(ctx, testAnswers())
	require.NoError(t, err)
	assert.Equal(t, StatusOK, st)
}

func TestLessonsLogEnvOverride(t *testing.T) {
	ctx := context.Background()
	env, _ := testEnv(t, "darwin")
	custom := filepath.Join(t.TempDir(), "logs", "lessons.md")
	env.Getenv = func(k string) string {
		if k == lessonsLogEnv {
			return custom
		}
		return ""
	}
	step := &LessonsLog{env: env}

	res, err := step.Apply(ctx, testAnswers())
	require.NoError(t, err)
	assert.True(t, res.Changed)
	_, err = os.Stat(custom)
	require.NoError(t, err)
	_, err = os.Stat(filepath.Join(env.Home, ".claude", "warren", "lessons-log.md"))
	assert.True(t, os.IsNotExist(err), "the default is not used when the variable is set")
}
