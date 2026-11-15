// Package sysexectest is a fake sysexec.Exec for tests: it records every command and answers
// from handlers registered by command line.
package sysexectest

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
	"fmt"
	"io"
	"os/exec"
	"strings"
	"sync"

	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

// Handler answers one command.
type Handler func(c sysexec.Command, stdin string) (sysexec.Result, error)

// Fake records commands and answers them. A command with no handler fails with exit 127, so a
// test never passes by running something it did not expect.
type Fake struct {
	mu       sync.Mutex
	handlers map[string]Handler
	programs map[string]string
	calls    []sysexec.Command
	stdins   []string
}

// New returns an empty Fake.
func New() *Fake {
	return &Fake{handlers: map[string]Handler{}, programs: map[string]string{}}
}

// On sets the handler for an exact command line.
func (f *Fake) On(line string, h Handler) *Fake {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.handlers[line] = h
	return f
}

// OnOutput answers line with exit 0 and stdout.
func (f *Fake) OnOutput(line, stdout string) *Fake {
	return f.On(line, func(sysexec.Command, string) (sysexec.Result, error) {
		return sysexec.Result{Stdout: stdout}, nil
	})
}

// OnExit answers line with the exit code.
func (f *Fake) OnExit(line string, code int) *Fake {
	return f.On(line, func(c sysexec.Command, _ string) (sysexec.Result, error) {
		if code == 0 {
			return sysexec.Result{}, nil
		}
		return sysexec.Result{ExitCode: code}, &sysexec.ExitError{Command: c.String(), Code: code}
	})
}

// Program makes name findable by LookPath, at path.
func (f *Fake) Program(name, path string) *Fake {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.programs[name] = path
	return f
}

// Remove makes name unfindable again.
func (f *Fake) Remove(name string) {
	f.mu.Lock()
	defer f.mu.Unlock()
	delete(f.programs, name)
}

// LookPath implements sysexec.Exec.
func (f *Fake) LookPath(name string) (string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if p, ok := f.programs[name]; ok {
		return p, nil
	}
	return "", fmt.Errorf("%s: %w", name, exec.ErrNotFound)
}

// Run implements sysexec.Exec.
func (f *Fake) Run(_ context.Context, c sysexec.Command) (sysexec.Result, error) {
	stdin := ""
	if c.Stdin != nil {
		b, _ := io.ReadAll(c.Stdin)
		stdin = string(b)
	}
	f.mu.Lock()
	f.calls = append(f.calls, c)
	f.stdins = append(f.stdins, stdin)
	h, ok := f.handlers[c.String()]
	f.mu.Unlock()
	if !ok {
		return sysexec.Result{ExitCode: 127}, &sysexec.ExitError{Command: c.String(), Code: 127, Stderr: "fake: no handler"}
	}
	return h(c, stdin)
}

// Calls returns every command line run, in order.
func (f *Fake) Calls() []string {
	f.mu.Lock()
	defer f.mu.Unlock()
	out := make([]string, 0, len(f.calls))
	for _, c := range f.calls {
		out = append(out, c.String())
	}
	return out
}

// Commands returns every command run, in order.
func (f *Fake) Commands() []sysexec.Command {
	f.mu.Lock()
	defer f.mu.Unlock()
	return append([]sysexec.Command(nil), f.calls...)
}

// Stdin returns what the n-th command was fed.
func (f *Fake) Stdin(n int) string {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.stdins[n]
}

// Ran reports whether any command line starts with prefix.
func (f *Fake) Ran(prefix string) bool {
	for _, c := range f.Calls() {
		if strings.HasPrefix(c, prefix) {
			return true
		}
	}
	return false
}
