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
	"os"
	"strings"

	golog "github.com/Bugs5382/go-log"
	"github.com/spf13/cobra"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/logging"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/steps"
)

type doctorOptions struct {
	json   bool
	config string
}

// doctorReport is what `warren doctor --json` prints.
type doctorReport struct {
	OK      bool           `json:"ok"`
	Answers string         `json:"answers"`
	Steps   []doctorResult `json:"steps"`
}

type doctorResult struct {
	Step    string `json:"step"`
	Status  string `json:"status"`
	Message string `json:"message,omitempty"`
}

// DoctorCmd builds `warren doctor`.
func DoctorCmd(d *deps) *cobra.Command {
	o := &doctorOptions{}
	cmd := &cobra.Command{
		Use:   "doctor",
		Short: "Check every step against the answers init last ran with",
		Long: `Runs every step's check and changes nothing. It reads the answers init saved in
~/.config/warren/answers.json, or the YAML file given with --config. Exits 3 when a step is
missing or has drifted.`,
		Args: cobra.NoArgs,
		RunE: func(cmd *cobra.Command, args []string) error {
			cmd.SilenceUsage = true
			return runDoctor(cmd, d, o)
		},
	}
	cmd.Flags().BoolVarP(&o.json, "json", "j", false, "Print the report as JSON")
	cmd.Flags().StringVarP(&o.config, "config", "c", "", "Check against this YAML answers file instead of the saved answers")
	return cmd
}

func loadDoctorAnswers(env steps.Env, config string) (answers.Answers, string, error) {
	if config != "" {
		a, err := answers.Load(config)
		return a, config, err
	}
	path := savedAnswersPath(env)
	if _, err := os.Stat(path); os.IsNotExist(err) {
		return answers.Answers{Version: 1}.WithDefaults(), "defaults (no saved answers; run warren init)", nil
	}
	a, err := answers.FromJSONFile(path)
	return a, path, err
}

func runDoctor(cmd *cobra.Command, d *deps, o *doctorOptions) error {
	ctx := cmd.Context()
	env := envFor(d)
	a, source, err := loadDoctorAnswers(env, o.config)
	if err != nil {
		return err
	}
	logging.L().Debug("warren doctor", golog.F("answers", source))

	rep := doctorReport{OK: true, Answers: source}
	var notOK []string
	for _, s := range steps.RegistryFor(env) {
		st, err := s.Check(ctx, a)
		st = statusOf(st, err)
		r := doctorResult{Step: s.Name(), Status: string(st)}
		if err != nil {
			r.Message = err.Error()
		}
		if st != steps.StatusOK && st != steps.StatusSkipped {
			rep.OK = false
			notOK = append(notOK, s.Name())
		}
		rep.Steps = append(rep.Steps, r)
	}

	out := cmd.OutOrStdout()
	if o.json {
		enc := json.NewEncoder(out)
		enc.SetIndent("", "  ")
		if err := enc.Encode(rep); err != nil {
			return codes.Wrap(codes.FileFailed, err, "write the report")
		}
	} else {
		for _, r := range rep.Steps {
			printLine(out, r.Step, r.Status, r.Message)
		}
	}
	if !rep.OK {
		return codes.New(codes.NotReady, "not in place: %s", strings.Join(notOK, ", "))
	}
	return nil
}
