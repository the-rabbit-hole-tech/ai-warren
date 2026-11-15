---
name: adopt-repo
description: Use when bringing an existing repo under governance: warren-apply-governance, labels, licence-header Taskfile fill and the .gitignore check.
---

# Bringing an existing repo under governance

1. On a branch, run `warren-apply-governance --sync --eco <eco>[/<variant>] <repo>`. `--sync` lays down the shared set (workflows, labels, PR, issue and discussion templates, community-health files, gitleaks, `CLAUDE.md` with the layout block, `AGENTS.md` when missing); `--eco` adds the ecosystem's CI files the repo lacks. Files the repo already has from `--eco` are kept. A repo the owner lists in its `scaffold/protected` is refused; never add `--force` without the owner's Yes. Nothing is staged or committed: review the diff and commit it on the branch. The owner's `scaffold/` folder decides the release-drafter config: a local `release-drafter.yml`, or none when the owner extends a shared one.
2. Seed the canonical labels with `gh label create --force` before opening the PR.
3. Fill the Taskfile `COMMON_LIC` with `<year> <holder>` before running `task license:fix`, or golic stamps the literal placeholders.
4. Check `.gitignore`: a whitelist-style ignore (`*` then re-includes) silently drops governance files. Replace it with a blocklist and confirm `git ls-files CLAUDE.md .github` lists them before pushing.
5. Write the repo's `.claude/settings.json` with `/warren:warren-repo` only when the repo needs its own overrides (the owner's org plugin supplies the rules, so a repo with no plugin list is still set up), and the ruleset with `warren-apply-ruleset <owner/repo>` when the repo has none.

See scaffold:governance for the scope.
