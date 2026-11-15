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
	"context"
	"os"
	"path/filepath"
	"strings"

	golog "github.com/Bugs5382/go-log"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/answers"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/codes"
	"github.com/the-rabbit-hole-tech/ai-warren/internal/sysexec"
)

// GuardSync runs the installed warren plugin's bin/warren-guard-sync, which copies the git hooks
// to ~/.config/warren/git-hooks. On a fresh machine (global core.hooksPath unset and
// ~/.config/git/hooks absent) it also links ~/.config/git/hooks to that copy and points
// core.hooksPath at the link. When either already points somewhere else it reports drift and
// changes nothing.
type GuardSync struct{ env Env }

// Name implements Step.
func (s *GuardSync) Name() string { return "guard-sync" }

func (s *GuardSync) link() string {
	return filepath.Join(s.env.Home, ".config", "git", "hooks")
}

func (s *GuardSync) dest() string {
	return filepath.Join(s.env.Home, ".config", "warren", "git-hooks")
}

// syncState is what the link and core.hooksPath look like.
type syncState struct {
	hooksPathSet   bool // core.hooksPath is set at all
	hooksPathOK    bool // and names the link
	linkExists     bool
	linkOK         bool // the link is a symlink to the copy
	copyHasVersion bool
}

func (s *GuardSync) state(ctx context.Context) (syncState, error) {
	var st syncState
	hp, err := s.env.globalGet(ctx, "core.hooksPath")
	if err != nil {
		return st, err
	}
	if strings.HasPrefix(hp, "~/") {
		hp = filepath.Join(s.env.Home, hp[2:])
	}
	st.hooksPathSet = hp != ""
	st.hooksPathOK = filepath.Clean(hp) == s.link()
	if _, err := os.Lstat(s.link()); err == nil {
		st.linkExists = true
		if target, err := os.Readlink(s.link()); err == nil {
			if !filepath.IsAbs(target) {
				target = filepath.Join(filepath.Dir(s.link()), target)
			}
			st.linkOK = filepath.Clean(target) == s.dest()
		}
	}
	if _, err := os.Stat(filepath.Join(s.dest(), "VERSION")); err == nil {
		st.copyHasVersion = true
	}
	s.env.Log.Trace("guard sync state", golog.F("hooks_path_set", st.hooksPathSet), golog.F("hooks_path_ok", st.hooksPathOK),
		golog.F("link_exists", st.linkExists), golog.F("link_ok", st.linkOK), golog.F("copy", st.copyHasVersion))
	return st, nil
}

func (s *GuardSync) drift(st syncState) error {
	var why []string
	if st.hooksPathSet && !st.hooksPathOK {
		why = append(why, "the global core.hooksPath names another folder")
	}
	if st.linkExists && !st.linkOK {
		why = append(why, s.link()+" is not a link to "+s.dest())
	}
	if len(why) == 0 {
		return nil
	}
	return codes.New(codes.GuardSyncDrift, "%s; warren changes neither, move it aside by hand", strings.Join(why, " and "))
}

// Check implements Step.
func (s *GuardSync) Check(ctx context.Context, _ answers.Answers) (Status, error) {
	st, err := s.state(ctx)
	if err != nil {
		return StatusMissing, err
	}
	if err := s.drift(st); err != nil {
		return StatusDrift, err
	}
	if st.hooksPathOK && st.linkOK && st.copyHasVersion {
		return StatusOK, nil
	}
	return StatusMissing, codes.New(codes.StepFailed, "the guard is not synced and linked yet")
}

// pluginRoot finds the installed warren plugin's folder: the folder a directory marketplace
// loads in place, or else the plugin cache copy.
func (s *GuardSync) pluginRoot(ctx context.Context, a answers.Answers) (string, error) {
	id := answers.DefaultPlugin
	for _, p := range a.Plugins {
		if strings.HasPrefix(p, "warren@") {
			id = p
			break
		}
	}
	list, err := s.env.installedPlugins(ctx)
	if err != nil {
		return "", err
	}
	for _, p := range list {
		if p.ID != id {
			continue
		}
		for _, dir := range []string{p.ReadFromFolder, p.InstallPath} {
			if dir == "" {
				continue
			}
			if fi, err := os.Stat(dir); err == nil && fi.IsDir() {
				s.env.Log.Debug("plugin root found", golog.F("plugin", id), golog.F("root", dir))
				return dir, nil
			}
		}
	}
	return "", codes.New(codes.PluginRootNotFound, "plugin %s is not installed, or its folder is gone; the plugins step installs it", id)
}

func (s *GuardSync) runSync(ctx context.Context, root string) (int, error) {
	script := filepath.Join(root, "bin", "warren-guard-sync")
	res, err := s.env.Exec.Run(ctx, sysexec.Command{Name: script, Args: []string{"--quiet"}, Env: []string{"CLAUDE_PLUGIN_ROOT=" + root}})
	code := sysexec.ExitCode(err)
	if err != nil && code < 0 {
		return code, codes.Wrap(codes.GuardSyncFailed, err, "run warren-guard-sync")
	}
	if err == nil {
		code = 0
	}
	s.env.Log.Debug("warren-guard-sync finished", golog.F("exit", code), golog.F("stderr", strings.TrimSpace(res.Stderr)))
	return code, nil
}

// Apply implements Step.
func (s *GuardSync) Apply(ctx context.Context, a answers.Answers) (Result, error) {
	st, err := s.state(ctx)
	if err != nil {
		return Result{}, err
	}
	if err := s.drift(st); err != nil {
		return Result{}, err
	}
	root, err := s.pluginRoot(ctx, a)
	if err != nil {
		return Result{}, err
	}
	code, err := s.runSync(ctx, root)
	if err != nil {
		return Result{}, err
	}
	changed := code == 3
	switch code {
	case 0, 3, 4:
		if st.hooksPathOK && st.linkOK {
			msg := "in sync"
			switch code {
			case 3:
				msg = "re-synced the guard copy"
			case 4:
				msg = "kept the installed guard: this plugin is older than the copy's"
			}
			return Result{Changed: changed, Message: msg}, nil
		}
	case 1:
	default:
		return Result{}, codes.New(codes.GuardSyncFailed, "warren-guard-sync exited %d (2 means the plugin's git-hooks folder is missing)", code)
	}

	// A fresh machine: link the hooks folder to the copy and point core.hooksPath at the link.
	if !st.linkExists {
		if err := os.MkdirAll(filepath.Dir(s.link()), 0o750); err != nil {
			return Result{}, codes.Wrap(codes.FileFailed, err, "make "+filepath.Dir(s.link()))
		}
		if err := os.Symlink(s.dest(), s.link()); err != nil {
			return Result{}, codes.Wrap(codes.FileFailed, err, "link "+s.link())
		}
		s.env.Log.Info("linked the global hooks folder", golog.F("link", s.link()), golog.F("target", s.dest()))
	}
	if !st.hooksPathSet {
		if _, err := s.env.run(ctx, "git", "config", "--global", "core.hooksPath", s.link()); err != nil {
			return Result{}, codes.Wrap(codes.ExecFailed, err, "set core.hooksPath")
		}
		s.env.Log.Info("set the global core.hooksPath", golog.F("path", s.link()))
	}
	code, err = s.runSync(ctx, root)
	if err != nil {
		return Result{}, err
	}
	if code != 0 && code != 3 && code != 4 {
		return Result{}, codes.New(codes.GuardSyncFailed, "warren-guard-sync still exits %d after linking", code)
	}
	return Result{Changed: true, Message: "synced and linked " + s.link() + " to " + s.dest()}, nil
}
