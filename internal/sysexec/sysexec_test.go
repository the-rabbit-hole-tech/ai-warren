package sysexec

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
	"strings"
	"testing"

	golog "github.com/Bugs5382/go-log"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestRealRunCapturesOutput(t *testing.T) {
	r := New(golog.Nop())
	res, err := r.Run(context.Background(), Command{Name: "sh", Args: []string{"-c", "cat; echo out; echo err >&2"}, Stdin: strings.NewReader("in\n")})
	require.NoError(t, err)
	assert.Equal(t, "in\nout\n", res.Stdout)
	assert.Equal(t, "err\n", res.Stderr)
}

func TestRealRunExitCode(t *testing.T) {
	r := New(golog.Nop())
	res, err := r.Run(context.Background(), Command{Name: "sh", Args: []string{"-c", "echo nope >&2; exit 3"}})
	require.Error(t, err)
	assert.Equal(t, 3, res.ExitCode)
	assert.Equal(t, 3, ExitCode(err))
	assert.Contains(t, err.Error(), "exited 3: nope")
}

func TestRealRunEnv(t *testing.T) {
	r := New(golog.Nop())
	res, err := r.Run(context.Background(), Command{Name: "sh", Args: []string{"-c", "echo $WARREN_TEST_VALUE"}, Env: []string{"WARREN_TEST_VALUE=x1"}})
	require.NoError(t, err)
	assert.Equal(t, "x1\n", res.Stdout)
}

func TestRealRunMissingProgram(t *testing.T) {
	r := New(golog.Nop())
	_, err := r.Run(context.Background(), Command{Name: "warren-no-such-program"})
	require.Error(t, err)
	assert.Equal(t, -1, ExitCode(err))
	_, err = r.LookPath("warren-no-such-program")
	assert.Error(t, err)
}
