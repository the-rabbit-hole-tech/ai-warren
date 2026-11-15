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
	"context"
	"fmt"
	"io"
	"path/filepath"
	"slices"
	"strings"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/logging"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/steps"
)

// savedAnswersPath is where init keeps the answers it ran with, for doctor.
func savedAnswersPath(env steps.Env) string {
	return filepath.Join(env.Home, ".config", "warren", "answers.json")
}

// envFor returns d's Env with a logger.
func envFor(d *deps) steps.Env {
	env := d.env()
	if env.Log == nil {
		env.Log = logging.L()
	}
	return env
}

// selectSteps returns the registry, narrowed to an --only group when one is given.
func selectSteps(env steps.Env, only string) []steps.Step {
	all := steps.RegistryFor(env)
	if only == "" {
		return all
	}
	names := steps.Groups[only]
	var out []steps.Step
	for _, s := range all {
		if slices.Contains(names, s.Name()) {
			out = append(out, s)
		}
	}
	return out
}

func validOnly(only string) error {
	if only == "" {
		return nil
	}
	if _, ok := steps.Groups[only]; !ok {
		return codes.New(codes.Usage, "--only %q is not one of machine, github, secrets", only)
	}
	return nil
}

// statusOf turns a Check error into the status to show when the step gave none.
func statusOf(st steps.Status, err error) steps.Status {
	if st == "" && err != nil {
		return steps.StatusMissing
	}
	return st
}

// printLine prints one step line: name, status and a note.
func printLine(w io.Writer, name string, status, note string) {
	_, _ = fmt.Fprintf(w, "%-15s %-8s %s\n", name, status, strings.TrimSpace(note))
}

// runSteps checks each step and applies the ones not ok, stopping at the first failure.
func runSteps(ctx context.Context, w io.Writer, list []steps.Step, a answers.Answers, dryRun bool) error {
	log := logging.L()
	for _, s := range list {
		log.Debug("step check", golog.F("step", s.Name()))
		st, err := s.Check(ctx, a)
		st = statusOf(st, err)
		log.Debug("step checked", golog.F("step", s.Name()), golog.F("status", string(st)))
		if st == steps.StatusOK {
			printLine(w, s.Name(), "ok", "")
			continue
		}
		if dryRun {
			note := "would apply"
			if st == steps.StatusSkipped {
				note = "would skip"
			}
			if err != nil {
				note += ": " + err.Error()
			}
			printLine(w, s.Name(), string(st), note)
			continue
		}
		log.Info("step apply", golog.F("step", s.Name()), golog.F("status", string(st)))
		res, err := s.Apply(ctx, a)
		if err != nil {
			printLine(w, s.Name(), "failed", err.Error())
			log.Error(err, "step failed", golog.F("step", s.Name()), golog.F("code", codes.Name(err)))
			return err
		}
		switch {
		case st == steps.StatusSkipped:
			printLine(w, s.Name(), "skipped", res.Message)
		case res.Changed:
			printLine(w, s.Name(), "changed", res.Message)
		default:
			printLine(w, s.Name(), "ok", res.Message)
		}
		log.Info("step done", golog.F("step", s.Name()), golog.F("changed", res.Changed))
	}
	return nil
}
