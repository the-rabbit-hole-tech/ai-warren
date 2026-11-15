// Package prompt asks the interactive init's questions, one at a time. The commands depend on
// the Prompter interface; Huh is the terminal implementation and tests use a fake.
package prompt

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
	"errors"

	"github.com/charmbracelet/huh"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
)

// Prompter asks one question per call.
type Prompter interface {
	// Select asks for one of options, starting on def.
	Select(title string, options []string, def string) (string, error)
	// Input asks for free text, starting with def.
	Input(title, def string) (string, error)
	// Confirm asks yes or no.
	Confirm(title, description string) (bool, error)
}

// Huh asks in the terminal with charmbracelet/huh.
type Huh struct{}

// Select implements Prompter.
func (Huh) Select(title string, options []string, def string) (string, error) {
	v := def
	opts := make([]huh.Option[string], 0, len(options))
	for _, o := range options {
		opts = append(opts, huh.NewOption(o, o))
	}
	err := huh.NewSelect[string]().Title(title).Options(opts...).Value(&v).Run()
	return v, wrap(err)
}

// Input implements Prompter.
func (Huh) Input(title, def string) (string, error) {
	v := def
	err := huh.NewInput().Title(title).Value(&v).Run()
	return v, wrap(err)
}

// Confirm implements Prompter.
func (Huh) Confirm(title, description string) (bool, error) {
	v := false
	err := huh.NewConfirm().Title(title).Description(description).Value(&v).Run()
	return v, wrap(err)
}

func wrap(err error) error {
	if err == nil {
		return nil
	}
	if errors.Is(err, huh.ErrUserAborted) {
		return codes.New(codes.PromptCancelled, "stopped")
	}
	return codes.Wrap(codes.PromptFailed, err, "ask")
}
