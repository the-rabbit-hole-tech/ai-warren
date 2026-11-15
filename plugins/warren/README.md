# warren

The always-on plugin of the ai-warren marketplace. Every person, machine and repo that uses
ai-warren has it.

## What it does

- **The always-on text** (`warren.md`): about 18 lines that reach every session through a
  `SessionStart` hook, because a plugin can't ship an always-loaded `CLAUDE.md`. Everything
  else comes as skills from the other plugins, loaded for the step at hand.
- **The git identity guard** (`git-hooks/_dispatch`): one identity per person per machine, read
  from the global git config (`guard.expectedLogin`, `guard.expectedName`,
  `hooks.expectedAuthorEmail`). When any of them is unset, every commit and push is blocked.
- **The pre-push scrub gate** (`git-hooks/scrub/`): secrets, attribution trailers, the AI-tell
  list in governed repos, and the org identifier scan for the orgs in `orgs.conf` and your local
  table, `~/.config/warren/scrub-orgs.conf`, which plugin updates never touch. Any error blocks the push.
- **The command guards** (`PreToolUse` on Bash): forbidden text and emoji in commits, issues and
  PRs, Conventional Commit titles, the push readiness check, the Marketplace release guard, and the
  hook-bypass guard: `--no-verify`, `git commit -n` and a `core.hooksPath` override or write are
  denied, because the identity guard and the scrub gate run as git hooks. Reading `core.hooksPath`
  stays allowed.
  Also: a tmux guard (`tmux-last-window-guard.sh`) that denies `kill-window`, or `kill-pane` on the
  last pane, when it would end the session by closing its last window, and a warning that never
  blocks: a hand-rolled `gh pr merge` loop with `sleep` (use `merge-green.sh`).
  Metadata and merge gates: `gh-meta-guard.sh` denies `gh issue create` without `--assignee`,
  `--milestone` and a `--label`, and `gh pr create` without `--assignee` and `--milestone`, and
  reminds to set the issue type after an issue create. `merge-yes-gate.sh` denies `gh pr merge` (and gh api merge
  calls) unless a marker `~/.claude/warren/merge-yes/<owner>__<repo>__<n>` under 7 days old exists. The
  `merge-yes-record.sh` PostToolUse hook on AskUserQuestion writes it when the answer starts with Yes
  and the question names `owner/repo` and `#<n>`; `bin/warren-yes <owner/repo> <n>...` writes it for a
  standing Yes. `merge-green.sh` checks the marker itself; `<org>/plan` repos are exempt.
  `to-be-deleted-guard.sh` denies `--add-topic to-be-deleted` (use the PUT form with that single topic).
  Skill-first gate: `skill-record.sh` (PostToolUse on the Skill tool) writes
  `~/.claude/warren/skills-loaded/<session_id>/<skill>`; `skill-gate.sh` denies a `gh` or `tmux` command
  with "Load skill <name> first" until this session has loaded the skill that `hooks/skill-gate.tsv` maps it to
  (add rows there to extend it; a skill that is not installed is not required; a subagent has its own session).
  The tmux guard also denies `kill-server`, `kill-session` on `WARREN_OPS_SESSION` / `WARREN_CODING_SESSION`
  (default `ops` / `work`), `kill-window` in a loop or behind xargs, and `send-keys` of `exit` or `C-d` at a last window.
  Quiet hooks: the hand-off inbox hook prints its "nothing is listening" and stale notes once per session. A repo's
  own settings should run its hook scripts as `f="${CLAUDE_PROJECT_DIR}/.claude/hooks/x.sh"; [ -f "$f" ] || exit 0; exec bash "$f"`,
  so a deleted worktree exits 0 silently instead of failing with 127 (this repo's settings do).
- **`warren-guard-sync`** (`bin/`): copies the git hooks to `~/.config/warren/git-hooks`, a path
  that never changes, because the plugin cache path changes with every version. It runs at the
  start of every session and checks that `~/.config/git/hooks` links to that copy and that the
  global `core.hooksPath` names the link. It never changes either one itself. It never downgrades
  the copy either: it records the plugin version beside it, and a session still running an older
  plugin leaves the copy alone and says so in one line.
- **Operator scripts** (`bin/`): shared operator scripts: `merge-green.sh`,
  `unreleased.sh`, `refresh-projects.sh`, `claude-trust.sh`, `open-ide.sh`, the hand-off page
  builders `backlog-page.py` and `bug-log-page.py`. Paths and orgs come from `WARREN_SETUP`,
  `WARREN_HANDOFF_SITE`, `WARREN_CATALOG`, `WARREN_CODE_ROOT`, `WARREN_ORGS` and `WARREN_CATALOG_ORG`. The `scripts` skill lists them.
- **The repo-ready check** (`bin/warren-repo-ready`, `hooks/repo-ready.sh`): prints `ready`,
  `not-a-repo`, `exempt`, `unknown-owner` or `not-set-up:<reason>` (`no-org-plugin`, `disabled`)
  for a folder. A repo's rules come from its GitHub owner's plugin (`warren-org-<name>` or a
  personal one, found in the marketplace named for the lowercased owner), enabled at user level, so
  a repo with no plugin list of its own is `ready` when that plugin is there. `unknown-owner` means
  no github.com remote, so nothing can be checked. At session start the hook tells the session when
  the owner's plugin is missing and points to `/warren:menu`. It is advisory and never blocks. `WARREN_ENFORCE=off` silences it;
  `WARREN_EXEMPT` (colon-separated, default none) lists folders to skip.

## The /warren menu

`/warren:menu` asks what you're trying to do and runs the flow for it: set up a new org, a project or
repo, or this repo; start a feature; review or release; update warren; set up a person's GitHub; this
machine's host file; and your password manager when that plugin is installed. Set up this repo
(`/warren:warren-repo`) and update warren (`/warren:warren-update`) are full flows over
`warren step repo-settings` and `warren step update`; the others run the skill in their plugin.

## Setting up a machine

`warren init` (the CLI in this repo) installs the plugin, sets the guard identity and links the
hooks on a new machine. On a machine that already has a guard, the link is moved by hand.
