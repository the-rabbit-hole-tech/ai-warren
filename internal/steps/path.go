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

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

// pathMarker marks the one line the path step adds, so it is added once.
const pathMarker = "# warren: Go-installed tools on PATH"

const pathLine = `export PATH="$HOME/go/bin:$PATH" ` + pathMarker

// Path makes sure ~/go/bin is on PATH, where `go install` puts tools, by adding one marked
// line to the shell rc file (~/.zshrc on macOS, ~/.bashrc on Linux).
type Path struct{ env Env }

// Name implements Step.
func (s *Path) Name() string { return "path" }

func (s *Path) rc() string {
	if s.env.GOOS == "darwin" {
		return filepath.Join(s.env.Home, ".zshrc")
	}
	return filepath.Join(s.env.Home, ".bashrc")
}

func (s *Path) goBin() string { return filepath.Join(s.env.Home, "go", "bin") }

func (s *Path) present() (bool, error) {
	for _, dir := range filepath.SplitList(s.env.Getenv("PATH")) {
		if filepath.Clean(dir) == s.goBin() {
			s.env.Log.Trace("go bin already on PATH")
			return true, nil
		}
	}
	body, err := os.ReadFile(s.rc())
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, codes.Wrap(codes.FileFailed, err, "read "+s.rc())
	}
	return strings.Contains(string(body), pathMarker), nil
}

// Check implements Step.
func (s *Path) Check(context.Context, answers.Answers) (Status, error) {
	ok, err := s.present()
	if err != nil {
		return StatusMissing, err
	}
	if !ok {
		return StatusMissing, codes.New(codes.StepFailed, "%s is not on PATH", s.goBin())
	}
	return StatusOK, nil
}

// Apply implements Step.
func (s *Path) Apply(context.Context, answers.Answers) (Result, error) {
	ok, err := s.present()
	if err != nil {
		return Result{}, err
	}
	if ok {
		return Result{Message: s.goBin() + " already on PATH"}, nil
	}
	body, err := os.ReadFile(s.rc())
	if err != nil && !os.IsNotExist(err) {
		return Result{}, codes.Wrap(codes.FileFailed, err, "read "+s.rc())
	}
	add := pathLine + "\n"
	if len(body) > 0 && !strings.HasSuffix(string(body), "\n") {
		add = "\n" + add
	}
	f, err := os.OpenFile(s.rc(), os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644) // #nosec G302 G304 -- a shell rc file in the person's home
	if err != nil {
		return Result{}, codes.Wrap(codes.FileFailed, err, "open "+s.rc())
	}
	if _, err := f.WriteString(add); err != nil {
		_ = f.Close()
		return Result{}, codes.Wrap(codes.FileFailed, err, "write "+s.rc())
	}
	if err := f.Close(); err != nil {
		return Result{}, codes.Wrap(codes.FileFailed, err, "close "+s.rc())
	}
	s.env.Log.Info("added go bin to PATH", golog.F("rc", s.rc()))
	return Result{Changed: true, Message: "added " + s.goBin() + " to PATH in " + s.rc()}, nil
}
