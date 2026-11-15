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
	"strings"

	golog "github.com/Bugs5382/go-log"
	"github.com/spf13/cobra"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/logging"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/steps"
)

type initOptions struct {
	config              string
	only                string
	dryRun              bool
	allowIdentityChange bool
	marketplaceSource   string
}

// InitCmd builds `warren init`.
func InitCmd(d *deps) *cobra.Command {
	o := &initOptions{}
	cmd := &cobra.Command{
		Use:   "init",
		Short: "Set up this machine: tools, marketplace, plugins and the git guard",
		Long: `Asks one question at a time, then runs every step that is not in place yet. With
--config it reads the answers from a YAML file and asks nothing, for agent machines and
containers. Steps already in place are left alone, so init is safe to run again.`,
		Args: cobra.NoArgs,
		PreRunE: func(cmd *cobra.Command, args []string) error {
			return validOnly(o.only)
		},
		RunE: func(cmd *cobra.Command, args []string) error {
			cmd.SilenceUsage = true
			return runInit(cmd, d, o)
		},
	}
	cmd.Flags().StringVarP(&o.config, "config", "c", "", "Read the answers from this YAML file and ask nothing")
	cmd.Flags().StringVarP(&o.only, "only", "o", "", "Run one group of steps: machine, github or secrets")
	cmd.Flags().BoolVarP(&o.dryRun, "dry-run", "n", false, "Check every step and say what would change, changing nothing")
	cmd.Flags().BoolVarP(&o.allowIdentityChange, "allow-identity-change", "a", false, "Let guard-identity replace a different identity already set")
	addMarketplaceSourceFlag(cmd, &o.marketplaceSource)
	return cmd
}

func runInit(cmd *cobra.Command, d *deps, o *initOptions) error {
	ctx := cmd.Context()
	log := logging.L()
	env := envFor(d)
	env.AllowIdentityChange = o.allowIdentityChange
	if o.marketplaceSource != "" {
		env.MarketplaceSource = o.marketplaceSource
	}
	log.Info("warren init", golog.F("unattended", o.config != ""), golog.F("only", o.only), golog.F("dry_run", o.dryRun))

	var a answers.Answers
	var err error
	if o.config != "" {
		a, err = answers.Load(o.config)
	} else {
		a, err = ask(ctx, d, env)
	}
	if err != nil {
		return err
	}

	out := cmd.OutOrStdout()
	if o.only == "secrets" {
		printLine(out, "secrets", "skipped", "the secrets steps are not built yet")
		return nil
	}
	if err := runSteps(ctx, out, selectSteps(env, o.only), a, o.dryRun); err != nil {
		return err
	}
	if o.dryRun {
		return nil
	}
	if err := answers.Save(savedAnswersPath(env), a); err != nil {
		return err
	}
	log.Info("answers saved for doctor", golog.F("path", savedAnswersPath(env)))
	return nil
}

// ask fills the answers interactively, one question at a time, then asks to go ahead.
func ask(ctx context.Context, d *deps, env steps.Env) (answers.Answers, error) {
	p := d.prompter
	a := answers.Answers{Version: 1}.WithDefaults()

	role, err := p.Select("What is this machine's role?", answers.Roles, "ops")
	if err != nil {
		return a, err
	}
	a.Role = role

	orgs, err := p.Input("Org plugins to install (plugin@marketplace, comma separated; blank for none)", "")
	if err != nil {
		return a, err
	}
	a.OrgPlugins = splitList(orgs)

	// Default to this machine's own guard identity, never another machine's.
	login := firstSet(ctx, env, "guard.expectedLogin")
	name := firstSet(ctx, env, "guard.expectedName", "user.name")
	email := firstSet(ctx, env, "hooks.expectedAuthorEmail", "user.email")
	if a.GitHub.Login, err = p.Input("GitHub login allowed to commit on this machine", login); err != nil {
		return a, err
	}
	if name == "" {
		name = a.GitHub.Login
	}
	if a.GitHub.Name, err = p.Input("Commit name", name); err != nil {
		return a, err
	}
	if a.GitHub.Email, err = p.Input("Commit email", email); err != nil {
		return a, err
	}
	a.GitHub.TokenEnv = "GH_TOKEN"

	summary := fmt.Sprintf("role %s, plugins %s, guard for %s <%s>", a.Role,
		strings.Join(append(append([]string{}, a.Plugins...), a.OrgPlugins...), ", "), a.GitHub.Login, a.GitHub.Email)
	ok, err := p.Confirm("Set up this machine?", summary)
	if err != nil {
		return a, err
	}
	if !ok {
		return a, codes.New(codes.PromptCancelled, "nothing changed")
	}
	return a, a.Validate()
}

func firstSet(ctx context.Context, env steps.Env, keys ...string) string {
	for _, k := range keys {
		if v, err := env.GlobalGitConfig(ctx, k); err == nil && v != "" {
			return v
		}
	}
	return ""
}

func splitList(s string) []string {
	out := []string{}
	for _, part := range strings.Split(s, ",") {
		if p := strings.TrimSpace(part); p != "" {
			out = append(out, p)
		}
	}
	return out
}
