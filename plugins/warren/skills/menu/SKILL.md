---
name: menu
description: Use when someone types /warren:menu, asks what warren can do, or a session says the owner's warren plugin is missing.
disable-model-invocation: true
---

# The warren menu

Ask with AskUserQuestion, one question at a time.

1. Find which ai-warren plugins are installed: `claude plugin list --json` (ids ending `@ai-warren`).
2. Ask "What are you trying to do?" with these groups:
   - **Set up**: a new org, a project or repo, or this repo.
   - **Work**: start a feature, or review or release.
   - **This machine**: update warren, set up a person's GitHub, this machine's host file, and your password manager.
3. Ask for the choice inside the group (up to 4 options). Show "Connect your password manager" only when `secrets@ai-warren` is installed.
4. Run the flow for the choice from the table below. To run a flow, read its skill file and follow it:
   for warren's own skills that's `${CLAUDE_PLUGIN_ROOT}/skills/<skill>/SKILL.md`; for another plugin,
   take its `installPath` from `claude plugin list --json` and read `<installPath>/skills/<skill>/SKILL.md`.
   Tell the person they can also type the slash command next time.
5. When the choice's plugin isn't installed, say which plugin it needs (`claude plugin install <plugin>@ai-warren`)
   and offer "Update warren" instead of failing.

| Group | Choice | Flow | Plugin |
|---|---|---|---|
| Set up | Set up a new org | `/scaffold:warren-org` | scaffold |
| Set up | Start a new project or repo | `/scaffold:warren-project` | scaffold |
| Set up | Set up this repo | `/warren:warren-repo` | warren |
| Work | Start a feature | `/operator:warren-feature` | operator |
| Work | Review or release | `/github:warren-release` | github |
| This machine | Update warren | `/warren:warren-update` | warren |
| This machine | Set up a person's GitHub | see below | warren |
| This machine | This machine's host file | `/warren:warren-host` | warren |
| This machine | Connect your password manager | `/secrets:warren-secrets` | secrets |

**Set up a person's GitHub** (a new person, or a person on a new machine): it changes who the git guard
lets commit, so it never runs as a side effect of anything else. The prompts need a real terminal: ask
the person to run `warren init --only github` in their own terminal, then run `warren doctor` here and
report what it shows. If `warren` isn't installed, point them at `docs/warren-cli.md` in ai-warren.
