// Package codes holds the coded errors warren reports. Each code has a stable number (carried
// through go-apperr) and a stable name such as WARREN-CONFIG-SECRET that people and the skills
// quote and match on.
package codes

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
	"strings"

	"github.com/Bugs5382/go-apperr"
)

// Code is one warren error code.
type Code struct {
	Num   int
	Name  string
	Cause string
}

// The codes. Numbers and names never change once released.
var (
	ConfigInvalid      = Code{1001, "WARREN-CONFIG-INVALID", "the answers file or JSON is not valid"}
	ConfigSecret       = Code{1002, "WARREN-CONFIG-SECRET", "the answers hold something that looks like a secret value"}
	Usage              = Code{1003, "WARREN-USAGE", "bad command line"}
	GuardNoIdentity    = Code{1101, "WARREN-GUARD-NO-IDENTITY", "the GitHub identity for the guard is not given"}
	GuardIdentityDrift = Code{1102, "WARREN-GUARD-IDENTITY-DRIFT", "a different guard identity is already set"}
	GuardSyncDrift     = Code{1103, "WARREN-GUARD-SYNC-DRIFT", "core.hooksPath or the hooks link points somewhere else"}
	GuardSyncFailed    = Code{1104, "WARREN-GUARD-SYNC-FAILED", "warren-guard-sync failed"}
	ToolsNoPackager    = Code{1201, "WARREN-TOOLS-NO-PACKAGER", "no package manager to install tools with"}
	ClaudeMissing      = Code{1202, "WARREN-CLAUDE-MISSING", "the claude CLI is not installed"}
	MarketplaceUnknown = Code{1203, "WARREN-MARKETPLACE-UNKNOWN", "no source is known for a marketplace"}
	PluginMissing      = Code{1204, "WARREN-PLUGIN-MISSING", "a plugin is not installed"}
	StepUnknown        = Code{1301, "WARREN-STEP-UNKNOWN", "no step has that name"}
	StepFailed         = Code{1302, "WARREN-STEP-FAILED", "a step failed"}
	NotReady           = Code{1303, "WARREN-NOT-READY", "doctor found a step missing or drifted"}
	PromptFailed       = Code{1401, "WARREN-PROMPT-FAILED", "an interactive question could not be asked"}
	PromptCancelled    = Code{1402, "WARREN-PROMPT-CANCELLED", "the person stopped at the confirm question"}
	ExecFailed         = Code{1501, "WARREN-EXEC-FAILED", "an external command failed"}
	FileFailed         = Code{1502, "WARREN-FILE-FAILED", "a file could not be read or written"}
	PluginRootNotFound = Code{1503, "WARREN-PLUGIN-ROOT-NOT-FOUND", "the installed plugin's folder could not be found"}
	SecretsNotBuiltYet = Code{1601, "WARREN-SECRETS-NOT-BUILT", "the secrets steps are not built yet"}
	RepoInvalid        = Code{1701, "WARREN-REPO-INVALID", "the repo answers are missing or not valid"}
	RepoNotSetUp       = Code{1702, "WARREN-REPO-NOT-SET-UP", "this repo has not opted in to its own plugin list (optional)"}
	RepoSettingsDrift  = Code{1703, "WARREN-REPO-SETTINGS-DRIFT", "the repo settings name a marketplace with another source"}
	UpdateAvailable    = Code{1801, "WARREN-UPDATE-AVAILABLE", "an installed ai-warren plugin is behind the marketplace"}
)

// All lists every code, for the registry and the docs.
var All = []Code{
	ConfigInvalid, ConfigSecret, Usage, GuardNoIdentity, GuardIdentityDrift, GuardSyncDrift,
	GuardSyncFailed, ToolsNoPackager, ClaudeMissing, MarketplaceUnknown, PluginMissing,
	StepUnknown, StepFailed, NotReady, PromptFailed, PromptCancelled, ExecFailed, FileFailed,
	PluginRootNotFound, SecretsNotBuiltYet, RepoInvalid, RepoNotSetUp, RepoSettingsDrift,
	UpdateAvailable,
}

// named shows a coded error as "<NAME>: <detail>", without go-apperr's "code N:" prefix, since
// the name is what people quote. The code still travels the chain underneath.
type named struct {
	msg   string
	coded error
}

func (e *named) Error() string { return e.msg }
func (e *named) Unwrap() error { return e.coded }

// New returns an error carrying c, with a message that starts with c's name.
func New(c Code, format string, args ...any) error {
	inner := fmt.Errorf("%s: %s", c.Name, fmt.Sprintf(format, args...))
	return &named{msg: inner.Error(), coded: apperr.Coded(c.Num, inner)}
}

// Wrap returns cause wrapped with c and a short context, keeping errors.Is on cause.
func Wrap(c Code, cause error, context string) error {
	inner := fmt.Errorf("%s: %s: %w", c.Name, context, cause)
	return &named{msg: inner.Error(), coded: apperr.Coded(c.Num, inner)}
}

// Is reports whether err carries c anywhere in its chain.
func Is(err error, c Code) bool {
	num, ok := apperr.Code(err)
	return ok && num == c.Num
}

// Name returns the name of the code err carries, or "" for an uncoded error.
func Name(err error) string {
	if err == nil {
		return ""
	}
	num, ok := apperr.Code(err)
	if !ok {
		return ""
	}
	for _, c := range All {
		if c.Num == num {
			return c.Name
		}
	}
	return ""
}

// Registry builds the go-apperr registry of every code, for Describe and the docs table.
func Registry() (*apperr.Registry, error) {
	entries := make([]apperr.Entry, 0, len(All))
	for _, c := range All {
		entries = append(entries, apperr.Entry{
			Code:   c.Num,
			Title:  strings.ToLower(strings.SplitN(strings.TrimPrefix(c.Name, "WARREN-"), "-", 2)[0]),
			Cause:  c.Cause,
			Symbol: strings.ReplaceAll(c.Name, "-", "_"),
		})
	}
	return apperr.NewRegistry(entries, apperr.WithService(1), apperr.WithCodeDigits(4))
}
