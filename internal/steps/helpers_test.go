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
	"testing"

	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec/sysexectest"
)

// testEnv returns an Env on a fake Exec with a temp home and an empty environment.
func testEnv(t *testing.T, goos string) (Env, *sysexectest.Fake) {
	t.Helper()
	fake := sysexectest.New()
	env := Env{
		Exec:   fake,
		GOOS:   goos,
		Home:   t.TempDir(),
		Getenv: func(string) string { return "" },
		IsRoot: true,
	}
	return env.withDefaults(), fake
}

func testAnswers() answers.Answers {
	return answers.Answers{
		Version: 1,
		Role:    "agent-machine",
		GitHub: answers.GitHubAnswers{
			Login: "testperson",
			Name:  "testperson",
			Email: "1+testperson@users.noreply.github.com",
		},
	}.WithDefaults()
}

// installs returns a handler that makes program findable, as an install would.
func installs(fake *sysexectest.Fake, program, path string) sysexectest.Handler {
	return func(sysexec.Command, string) (sysexec.Result, error) {
		fake.Program(program, path)
		return sysexec.Result{}, nil
	}
}
