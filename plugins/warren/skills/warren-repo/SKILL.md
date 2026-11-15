---
name: warren-repo
description: Use when setting up an existing repo for ai-warren, from the warren menu's "Set up this repo".
disable-model-invocation: true
---

# Set up this repo

Declares the repo's marketplaces and plugins in its settings and installs them for the repo, through
`warren step repo-settings`. This is optional: the repo's rules come from its GitHub owner's org plugin
(enabled at user level), so a repo without this file is not "not set up". Use it when the repo needs
its own plugin list. The step keeps every key the settings file already has.

1. Find the repo's top folder: `git rev-parse --show-toplevel`. Not a git repo: stop and say so.
2. Find its visibility: `gh repo view --json visibility -q .visibility` (lowercase it). No GitHub
   remote: ask Private or Public.
   - A **public** repo keeps the plugin settings local (`.claude/settings.local.json`, kept out of git
     through the repo's own `.git/info/exclude`), so the private marketplace's name is never committed.
   - Any other repo gets `.claude/settings.json`, which is committed.
3. Ask which plugins the repo uses (multiSelect): **github** and **coding** (most repos), **design**,
   **handoff**; operator and scaffold through Other. warren is always declared.
4. Build the answers and check first:
   ```bash
   printf '%s' '{"version":1,"repo":{"dir":"<top>","visibility":"<visibility>","plugins":["github@ai-warren","coding@ai-warren"]}}' \
     | warren step repo-settings --check --answers -
   ```
   Show the person the `message` (what it would declare, enable and install) and ask Yes or No.
5. On Yes run the same command without `--check` and report the JSON result. Status `drift` means the
   settings already name the marketplace with another source: show it and stop; never edit it by hand
   without the person's Yes.
6. Run `warren-repo-ready` when it's on PATH and report the status (`ready` means the owner's plugin supplies the rules; `not-set-up:no-org-plugin` or `disabled` means install or enable it). Say the plugins load in a new session
   or after `/reload-plugins`.
7. For a committed settings file, the change goes through the normal flow (issue, branch, PR); never
   commit it to the default branch.

A repo with no shared governance yet (no `CLAUDE.md` layout block, no `.github/workflows`) gets it
first with `warren-apply-governance` from the scaffold plugin (see scaffold:adopt-repo), on the same
branch.

If `warren` isn't on PATH, say so and point at `docs/warren-cli.md` in ai-warren.
