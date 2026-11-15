// Command warren sets up a machine for the ai-warren plugins: the tools, the marketplace and
// plugins, and the git identity guard. See `warren --help`.
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
	"fmt"
	"io"
	"os"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/commands"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/logging"
)

// Exit statuses. They are part of the CLI contract: the skills and scripts that call warren act
// on them.
const (
	exitOK       = 0 // every step done, or doctor found everything in place
	exitFailed   = 1 // a step or an external command failed
	exitUsage    = 2 // bad command line, or the answers are invalid or hold a secret
	exitNotReady = 3 // doctor found a step missing or drifted
	exitDrift    = 4 // the guard identity or hooks link is set differently; nothing was changed
)

func main() {
	logging.Init(false)
	os.Exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr))
}

// run executes warren with args and returns the process exit status.
func run(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	root := commands.RootCmd()
	root.SetArgs(args)
	root.SetIn(stdin)
	root.SetOut(stdout)
	root.SetErr(stderr)
	// run reports the error itself, once, with the matching exit status.
	root.SilenceErrors = true

	err := root.Execute()
	code := exitCodeFor(err)
	if err != nil {
		logging.L().Debug("warren failed", golog.F("exit", code), golog.F("code", codes.Name(err)))
		_, _ = fmt.Fprintf(stderr, "warren: %v\n", err)
	}
	return code
}

func exitCodeFor(err error) int {
	switch {
	case err == nil:
		return exitOK
	case codes.Is(err, codes.Usage), codes.Is(err, codes.ConfigInvalid), codes.Is(err, codes.ConfigSecret),
		codes.Is(err, codes.StepUnknown):
		return exitUsage
	case codes.Is(err, codes.NotReady):
		return exitNotReady
	case codes.Is(err, codes.GuardIdentityDrift), codes.Is(err, codes.GuardSyncDrift):
		return exitDrift
	default:
		return exitFailed
	}
}
