package main

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
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

func TestRunExitCodes(t *testing.T) {
	secret := filepath.Join(t.TempDir(), "secret.yaml")
	require.NoError(t, os.WriteFile(secret, []byte("version: 1\nrole: ops\ngithub:\n  login: x\n  token: ghp_x\n"), 0o600))

	cases := []struct {
		name   string
		args   []string
		stdin  string
		exit   int
		stderr string
	}{
		{"help", []string{}, "", exitOK, ""},
		{"version", []string{"version"}, "", exitOK, ""},
		{"unknown command", []string{"nope"}, "", exitUsage, "WARREN-USAGE"},
		{"unknown flag", []string{"init", "--nope"}, "", exitUsage, "WARREN-USAGE"},
		{"bad only", []string{"init", "--only", "all"}, "", exitUsage, "WARREN-USAGE"},
		{"secret in config", []string{"init", "--config", secret}, "", exitUsage, "WARREN-CONFIG-SECRET"},
		{"missing config", []string{"init", "--config", filepath.Join(t.TempDir(), "none.yaml")}, "", exitUsage, "WARREN-CONFIG-INVALID"},
		{"unknown step", []string{"step", "nope", "--answers", "-"}, "{}", exitUsage, "WARREN-STEP-UNKNOWN"},
		{"step without answers", []string{"step", "tools"}, "", exitUsage, "WARREN-USAGE"},
		{"step no identity", []string{"step", "guard-identity", "--answers", "-"}, `{"version":1}`, exitFailed, "WARREN-GUARD-NO-IDENTITY"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			var out, errOut bytes.Buffer
			code := run(c.args, strings.NewReader(c.stdin), &out, &errOut)
			assert.Equal(t, c.exit, code, "stderr: %s", errOut.String())
			if c.stderr != "" {
				assert.Contains(t, errOut.String(), c.stderr)
			}
		})
	}
}

func TestExitCodeFor(t *testing.T) {
	assert.Equal(t, exitOK, exitCodeFor(nil))
	assert.Equal(t, exitNotReady, exitCodeFor(codes.New(codes.NotReady, "x")))
	assert.Equal(t, exitDrift, exitCodeFor(codes.New(codes.GuardIdentityDrift, "x")))
	assert.Equal(t, exitDrift, exitCodeFor(codes.New(codes.GuardSyncDrift, "x")))
	assert.Equal(t, exitFailed, exitCodeFor(codes.New(codes.ExecFailed, "x")))
	assert.Equal(t, exitFailed, exitCodeFor(errors.New("plain")))
}

// TestVersionLdflags builds the binary the way GoReleaser does and checks the stamp.
func TestVersionLdflags(t *testing.T) {
	if testing.Short() {
		t.Skip("builds the binary")
	}
	bin := filepath.Join(t.TempDir(), "warren")
	build := exec.Command("go", "build", "-o", bin, "-ldflags", // #nosec G204 -- fixed arguments, test only
		"-X github.com/Bugs5382/go-buildinfo.Version=v9.8.7 -X github.com/Bugs5382/go-buildinfo.Commit=abc1234", ".")
	build.Env = append(build.Environ(), "CGO_ENABLED=0")
	out, err := build.CombinedOutput()
	require.NoError(t, err, string(out))

	got, err := exec.Command(bin, "version").Output() // #nosec G204 -- binary built above
	require.NoError(t, err)
	assert.True(t, strings.HasPrefix(string(got), "v9.8.7\ncommit abc1234\n"), "got %q", got)
}
