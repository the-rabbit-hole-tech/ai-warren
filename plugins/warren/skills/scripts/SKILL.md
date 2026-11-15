---
name: scripts
description: Use when you need one of the operator scripts: merge a green PR, list unreleased work, refresh the package catalog, build backlog or bug-log pages, trust folders, open an IDE.
---

# Operator scripts

The scripts live in the warren plugin's `bin/` (`${CLAUDE_PLUGIN_ROOT}/bin`). Paths and orgs
come from env: `WARREN_SETUP` (default `~/.warren`), `WARREN_HANDOFF_SITE` (default
`$WARREN_SETUP/handoff-site`), `WARREN_CATALOG` (default `~/.claude/warren/catalog.md`),
`WARREN_CODE_ROOT` (required by `claude-trust.sh`), `WARREN_ORGS` (for `unreleased.sh`) and
`WARREN_CATALOG_ORG` (required by `refresh-projects.sh`).
Run a script only for the job it names; read its header comment first.

## Everyday

- `merge-green.sh <owner/repo> <pr> <summary...>`: squash-merges a PR only when it is open, mergeable and has no failing or pending checks; posts the closing summary first. Needs the owner's Yes marker first (`warren-yes <owner/repo> <n>`, or the approval answer). Exits 0 skip, 2 not green, 3 refused, 4 no Yes on record.
- `unreleased.sh [org ...]`: lists draft releases, open release-please PRs and commits since the last release per repo (no args: the orgs in `$WARREN_ORGS`).
- `refresh-projects.sh [out-file]`: regenerates the published-package catalog of `$WARREN_CATALOG_ORG` to `$WARREN_CATALOG`; run it after every release.
- `claude-trust.sh <dir>... | --all`: marks folders under `$WARREN_CODE_ROOT` as trusted in `~/.claude.json`, so a new window opens straight to the prompt.
- `open-ide.sh <repo-dir>`: opens a repo in GoLand (Go) or WebStorm (anything else).
- `backlog-page.py [--read] [--page F/S]`: writes the backlog board, the page `backlog/board` in the site's own Backlog folder (not under OPS), from `backlog.json`, or with `--read` prints the picks that were sent (`START`, `HOLD | comment` means revise it, `HOLD (sent)`, `HOLD (default)` for nothing sent) and any `DROP requested`. Run as `python3 -I`.
- `bug-log-page.py --folder <project> --json <bug-log.json>`: writes a bug-log reference page on the hand-off site. Run as `python3 -I`.
- `fleet-run <repos-file> "<prompt>" [--jobs N] [--tools ...] [--dry-run]`: runs one headless `claude -p` prompt in each listed repo, 4 at a time by default (never all at once), one log per repo under `~/.claude/warren/fleet-logs/`. For the same change across many repos (a toolchain bump, a hook removal). `--dry-run` first, tell the owner the repo count (every run costs tokens), and the prompt says to work in a worktree and to commit and push as separate commands. Merges still need the owner's Yes.
