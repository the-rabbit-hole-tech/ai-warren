// Package logging builds the go-log logger warren logs through. Logs go to stderr so they never
// mix with what a command prints on stdout (`warren doctor --json`, `warren step`).
package logging

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
	"io"
	"os"
	"strings"
	"sync/atomic"

	golog "github.com/Bugs5382/go-log"
)

// service is the name go-log stamps on every line.
const service = "warren"

var current atomic.Pointer[golog.TraceLogger]

func init() {
	Init(false)
}

// L returns the logger warren logs through.
func L() golog.TraceLogger {
	return *current.Load()
}

// Init builds the logger. A valid LOG_LEVEL wins; otherwise verbose selects trace and the
// default is info. The format is console text unless LOG_FORMAT says json. Under `go test`
// logging is off.
func Init(verbose bool) {
	l := golog.Nop()
	if !isTest() {
		l = build(verbose, os.Stderr)
	}
	current.Store(&l)
}

// Use makes l the logger every package logs through. Tests use it to capture logs.
func Use(l golog.TraceLogger) {
	current.Store(&l)
}

func build(verbose bool, out io.Writer) golog.TraceLogger {
	level := golog.LevelInfo
	if verbose {
		level = golog.LevelTrace
	}
	return golog.NewLoggerWithOptions(service,
		golog.WithOutput(out),
		golog.WithDefaultFormat(golog.FormatConsole),
		golog.WithDefaultLevel(level),
	)
}

func isTest() bool {
	return strings.HasSuffix(os.Args[0], ".test") ||
		strings.Contains(strings.Join(os.Args, " "), "-test.")
}
