// Package sysexec runs the external commands warren drives (brew, apt-get, sudo, gh, claude,
// git, curl and bash) behind one interface, so the steps can be tested with a fake. The real
// runner logs every call with its target, duration and outcome. It never logs stdin, which is
// where a token travels.
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
	"bytes"
	"context"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"strings"
	"time"

	golog "github.com/Bugs5382/go-log"
)

// Command is one external command.
type Command struct {
	Name string
	Args []string
	// Env is added to the inherited environment, as KEY=value pairs.
	Env []string
	// Stdin is fed to the command. It is never logged.
	Stdin io.Reader
	// Dir is the folder the command runs in; empty means the current one.
	Dir string
}

// String is the command line, used in logs and by the fake to match commands.
func (c Command) String() string {
	return strings.TrimSpace(c.Name + " " + strings.Join(c.Args, " "))
}

// Result is what a finished command printed and how it exited.
type Result struct {
	Stdout   string
	Stderr   string
	ExitCode int
}

// ExitError is returned when a command ran and exited non-zero.
type ExitError struct {
	Command string
	Code    int
	Stderr  string
}

func (e *ExitError) Error() string {
	msg := fmt.Sprintf("%s exited %d", e.Command, e.Code)
	if s := strings.TrimSpace(e.Stderr); s != "" {
		msg += ": " + lastLine(s)
	}
	return msg
}

// ExitCode returns the exit status err carries, or -1 when it is not an ExitError.
func ExitCode(err error) int {
	var ee *ExitError
	if errors.As(err, &ee) {
		return ee.Code
	}
	return -1
}

// Exec runs commands and finds programs.
type Exec interface {
	// Run runs c and waits. The error is an *ExitError when it exits non-zero, or another error
	// when it could not start.
	Run(ctx context.Context, c Command) (Result, error)
	// LookPath finds a program on PATH, or checks an absolute path is executable.
	LookPath(name string) (string, error)
}

// Real is the Exec that runs commands on this machine.
type Real struct {
	log golog.TraceLogger
}

// New returns the real Exec, logging through log.
func New(log golog.TraceLogger) *Real {
	return &Real{log: log}
}

// LookPath implements Exec.
func (r *Real) LookPath(name string) (string, error) {
	p, err := exec.LookPath(name)
	r.log.Trace("look up program", golog.F("program", name), golog.F("found", err == nil), golog.F("path", p))
	return p, err
}

// Run implements Exec.
func (r *Real) Run(ctx context.Context, c Command) (Result, error) {
	line := c.String()
	r.log.Debug("external call start", golog.F("target", line), golog.F("stdin", c.Stdin != nil))
	start := time.Now()

	cmd := exec.CommandContext(ctx, c.Name, c.Args...) // #nosec G204 -- the steps build fixed commands
	if len(c.Env) > 0 {
		cmd.Env = append(cmd.Environ(), c.Env...)
	}
	cmd.Stdin = c.Stdin
	cmd.Dir = c.Dir
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()

	res := Result{Stdout: stdout.String(), Stderr: stderr.String()}
	elapsed := time.Since(start).Milliseconds()
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) {
			res.ExitCode = ee.ExitCode()
			r.log.Debug("external call done", golog.F("target", line), golog.F("duration_ms", elapsed),
				golog.F("outcome", "exit"), golog.F("exit", res.ExitCode))
			r.log.Trace("external call stderr", golog.F("target", line), golog.F("stderr", lastLine(res.Stderr)))
			return res, &ExitError{Command: line, Code: res.ExitCode, Stderr: res.Stderr}
		}
		r.log.Error(err, "external call could not start", golog.F("target", line), golog.F("duration_ms", elapsed))
		return res, fmt.Errorf("run %s: %w", line, err)
	}
	r.log.Debug("external call done", golog.F("target", line), golog.F("duration_ms", elapsed),
		golog.F("outcome", "ok"), golog.F("exit", 0))
	return res, nil
}

func lastLine(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.LastIndexByte(s, '\n'); i >= 0 {
		return s[i+1:]
	}
	return s
}
