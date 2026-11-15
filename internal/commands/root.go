// Package commands holds warren's Cobra commands, one constructor per file.
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
	"github.com/spf13/cobra"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/logging"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/prompt"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/steps"
)

// deps are what the commands need from outside: the machine and the person.
type deps struct {
	env      func() steps.Env
	prompter prompt.Prompter
}

// Option replaces one of the commands' dependencies. Tests use them.
type Option func(*deps)

// WithEnv runs the steps against env instead of this machine.
func WithEnv(env steps.Env) Option {
	return func(d *deps) { d.env = func() steps.Env { return env } }
}

// WithPrompter asks the interactive questions through p.
func WithPrompter(p prompt.Prompter) Option {
	return func(d *deps) { d.prompter = p }
}

// RootCmd builds the warren command and its subcommands.
func RootCmd(opts ...Option) *cobra.Command {
	var verbose bool
	d := &deps{
		env:      func() steps.Env { return steps.DefaultEnv(logging.L()) },
		prompter: prompt.Huh{},
	}
	for _, o := range opts {
		o(d)
	}

	rootCmd := &cobra.Command{
		Use:   "warren",
		Short: "Set up this machine for the ai-warren plugins and check it stays set up",
		Long: `warren installs the tools, the ai-warren marketplace and plugins, and the git identity
guard on this machine. "warren init" asks one question at a time; "warren init --config <file>"
runs the same steps with no questions. "warren doctor" checks every step.`,
		Args: func(cmd *cobra.Command, args []string) error {
			if len(args) > 0 {
				return codes.New(codes.Usage, "unknown command %q for warren", args[0])
			}
			return nil
		},
		PersistentPreRun: func(cmd *cobra.Command, args []string) {
			if verbose {
				logging.Init(true)
			}
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			logging.L().Debug("no command given, printing help")
			return cmd.Help()
		},
	}
	rootCmd.CompletionOptions.DisableDefaultCmd = true
	rootCmd.SetFlagErrorFunc(func(_ *cobra.Command, err error) error {
		return codes.Wrap(codes.Usage, err, "flags")
	})
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "Verbose output (trace logging)")

	rootCmd.AddCommand(VersionCmd())
	rootCmd.AddCommand(InitCmd(d))
	rootCmd.AddCommand(StepCmd(d))
	rootCmd.AddCommand(DoctorCmd(d))
	return rootCmd
}
