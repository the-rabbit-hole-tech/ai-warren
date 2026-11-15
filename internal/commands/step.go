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
	"encoding/json"

	golog "github.com/Bugs5382/go-log"
	"github.com/spf13/cobra"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/logging"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/steps"
)

type stepOptions struct {
	answers           string
	check             bool
	marketplaceSource string
}

// stepReport is what `warren step` prints: one JSON object.
type stepReport struct {
	Step    string `json:"step"`
	Status  string `json:"status"`
	Changed bool   `json:"changed"`
	Message string `json:"message,omitempty"`
	Error   string `json:"error,omitempty"`
	Code    string `json:"code,omitempty"`
}

// StepCmd builds `warren step <name> --answers -`, the entry the skills call.
func StepCmd(d *deps) *cobra.Command {
	o := &stepOptions{}
	cmd := &cobra.Command{
		Use:   "step <name>",
		Short: "Run one step with answers as JSON and print the result as JSON",
		Long: `Runs one step (tools, marketplace, plugins, guard-identity, guard-sync, gh-auth, path,
or the on-demand repo-settings and update) with the answers read as JSON from a file, or from
stdin with "--answers -". Prints one JSON object. With --check it only checks.`,
		Args: func(cmd *cobra.Command, args []string) error {
			if len(args) != 1 {
				return codes.New(codes.Usage, "warren step takes one step name")
			}
			return nil
		},
		PreRunE: func(cmd *cobra.Command, args []string) error {
			if o.answers == "" {
				return codes.New(codes.Usage, "--answers is required (a JSON file, or - for stdin)")
			}
			return nil
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			cmd.SilenceUsage = true
			return runStep(cmd, d, o, args[0])
		},
	}
	cmd.Flags().StringVarP(&o.answers, "answers", "A", "", "Answers as JSON: a file, or - for stdin")
	cmd.Flags().BoolVarP(&o.check, "check", "k", false, "Only check the step")
	addMarketplaceSourceFlag(cmd, &o.marketplaceSource)
	return cmd
}

func runStep(cmd *cobra.Command, d *deps, o *stepOptions, name string) error {
	ctx := cmd.Context()
	env := envFor(d)
	if o.marketplaceSource != "" {
		env.MarketplaceSource = o.marketplaceSource
	}
	step, err := steps.Find(steps.AllFor(env), name)
	if err != nil {
		return err
	}
	var a answers.Answers
	if o.answers == "-" {
		a, err = answers.FromJSON(cmd.InOrStdin())
	} else {
		a, err = answers.FromJSONFile(o.answers)
	}
	if err != nil {
		return err
	}
	logging.L().Debug("warren step", golog.F("step", name), golog.F("check_only", o.check))

	rep := stepReport{Step: name}
	st, cerr := step.Check(ctx, a)
	rep.Status = string(statusOf(st, cerr))
	var runErr error
	switch {
	case o.check:
		if cerr != nil && st != steps.StatusSkipped {
			rep.Message = cerr.Error()
		}
		if st == "" && cerr != nil {
			runErr = cerr
		}
	case st == steps.StatusOK:
		res, err := step.Apply(ctx, a)
		rep.Message, runErr = res.Message, err
	default:
		res, err := step.Apply(ctx, a)
		rep.Changed, rep.Message, runErr = res.Changed, res.Message, err
		if err == nil && res.Changed {
			rep.Status = string(steps.StatusOK)
		}
	}
	if runErr != nil {
		rep.Error = runErr.Error()
		rep.Code = codes.Name(runErr)
	}
	enc := json.NewEncoder(cmd.OutOrStdout())
	if err := enc.Encode(rep); err != nil {
		return codes.Wrap(codes.FileFailed, err, "write the result")
	}
	return runErr
}
