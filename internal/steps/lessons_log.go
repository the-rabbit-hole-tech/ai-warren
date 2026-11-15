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

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

// lessonsLogEnv overrides where the lessons log lives.
const lessonsLogEnv = "WARREN_LESSONS_LOG"

// lessonsLogHeader is the one line a new lessons log starts with.
const lessonsLogHeader = "# Lessons log (first occurrences, one dated line each; see operator:self-learning)"

// LessonsLog makes sure the lessons log exists. The log lives only on this machine, in no repo,
// at ~/.claude/warren/lessons-log.md unless WARREN_LESSONS_LOG names another file.
type LessonsLog struct{ env Env }

// Name implements Step.
func (s *LessonsLog) Name() string { return "lessons-log" }

func (s *LessonsLog) file() string {
	if p := s.env.Getenv(lessonsLogEnv); p != "" {
		return p
	}
	return filepath.Join(s.env.Home, ".claude", "warren", "lessons-log.md")
}

func (s *LessonsLog) present() (bool, error) {
	_, err := os.Stat(s.file())
	if os.IsNotExist(err) {
		return false, nil
	}
	if err != nil {
		return false, codes.Wrap(codes.FileFailed, err, "stat "+s.file())
	}
	return true, nil
}

// Check implements Step.
func (s *LessonsLog) Check(context.Context, answers.Answers) (Status, error) {
	ok, err := s.present()
	if err != nil {
		return StatusMissing, err
	}
	if !ok {
		return StatusMissing, codes.New(codes.StepFailed, "no lessons log at %s", s.file())
	}
	return StatusOK, nil
}

// Apply implements Step. An existing log is never touched.
func (s *LessonsLog) Apply(context.Context, answers.Answers) (Result, error) {
	ok, err := s.present()
	if err != nil {
		return Result{}, err
	}
	if ok {
		return Result{Message: "lessons log already at " + s.file()}, nil
	}
	if err := os.MkdirAll(filepath.Dir(s.file()), 0o700); err != nil {
		return Result{}, codes.Wrap(codes.FileFailed, err, "create "+filepath.Dir(s.file()))
	}
	f, err := os.OpenFile(s.file(), os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0o600) // #nosec G304 -- the person's own lessons log
	if err != nil {
		return Result{}, codes.Wrap(codes.FileFailed, err, "create "+s.file())
	}
	if _, err := f.WriteString(lessonsLogHeader + "\n"); err != nil {
		_ = f.Close()
		return Result{}, codes.Wrap(codes.FileFailed, err, "write "+s.file())
	}
	if err := f.Close(); err != nil {
		return Result{}, codes.Wrap(codes.FileFailed, err, "close "+s.file())
	}
	s.env.Log.Info("created lessons log", golog.F("path", s.file()))
	return Result{Changed: true, Message: "created " + s.file()}, nil
}
