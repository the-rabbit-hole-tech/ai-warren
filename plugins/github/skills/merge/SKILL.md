---
name: merge
description: Use when a PR is ready for the owner's approval, about to be merged, or its CI needs checking: the one-question-per-PR ask, Yes marker, merge on GitHub, green requirement, runners, workflow shape.
---

# Approving, merging and CI

## approve-merge

- **PR approvals:** one AskUserQuestion per PR, "Do you approve <owner>/<repo>@PR#<n>?", batched up to 4.
  - **Linked PRs:** when one PR depends on another, ask one question covering the set, naming each PR and the merge order, with the dependency first. There's no separate Yes or No on the dependency. A Yes merges them in order; a No holds them all.
  - **Yes:** the owner's manual review, PRs to the shared rules repo included. Post the closing summary, squash-merge on GitHub and delete the branch.
  - **No:** leave it open and take notes.
  - **Open browser to review:** run `gh pr view <n> -R <repo> --web`, then ask again.
  - Merging or closing always deletes the branch on GitHub and locally and removes its worktree; confirm they're gone before reporting the PR done.
- **The Yes marker:** the warren `merge-yes` hook denies `gh pr merge` and gh api merge calls unless `~/.claude/warren/merge-yes/<owner>__<repo>__<n>` is under 7 days old. Your AskUserQuestion with a Yes answer writes it (the question must name `<owner>/<repo>` and `#<n>`; one question may list several PRs). For a standing Yes the owner gave in words, run `warren-yes <owner/repo> <n> [n...]`. `merge-green.sh` checks the marker itself. Plan repos need none.
- **Merging:** never locally; always on GitHub, via PR. PRs into any parent branch are rebase-merged, not squashed, so each commit keeps its canonical author and the final PR passes DCO; the default branch stays squash-only.
  - **Merge-on-green** is never standing permission. The owner sometimes grants it for one day or one batch; it covers only that day's work and expires with it. Without a grant, every merge waits for the owner's Yes.
- **Plan repos merge without approval:** for any `<org>/plan` repo, still use an issue, a branch and a PR (never a direct push to main), then merge it yourself once its checks pass. Every other repo still waits for the owner's Yes.

## ci

- **"Merge-ready":** mergeable AND CI green, both read from GitHub's API at claim time, never from a cached digest or another agent's verdict. Classify a red pipeline as code or environment before recommending anything.
- **CI must be green** before a PR is done or merged, unless the owner says otherwise. Check with `gh pr checks <n>`; fix real causes, never bypass.
  - **Linux-only repos:** repos whose build or tests can't run on macOS have no local pre-push build/lint/test gate; CI on GitHub-hosted runners is their gate. Run what can run locally, push once, and let CI decide. The identity and forbidden-text guard still runs everywhere.
- **GitHub Actions minute-saving pattern:** every workflow follows this plugin's pattern (an org may keep its own variant, named in its org plugin). Write any new or changed workflow this way from the start.
  - **Runners:** every repo in every org runs on GitHub-hosted runners. There are no self-hosted runners anywhere. Private repos spend paid minutes, so the rest of this pattern matters more for them. **Only exception:** a project's own CLAUDE.md may grant a dated, scoped exception for a self-hosted runner on that org's **private** repos only, never a public repo; it ends on its date, and the workflows go back to GitHub-hosted runners.
  - **Shape:** one `checks` job holds the small checks. Build and Security run on PRs only; release, publish and SBOM run on main or tags. Draft PRs are skipped, every job sets `timeout-minutes`, tools are pinned prebuilt binaries (checksum-checked), and there are no no-op jobs.

## Before calling a PR done

Run `gh pr checks <n> --watch` after the push. A PR is done when CI is green or when you have reported the specific failing check. A status report cites evidence (the `gh pr view --json state,statusCheckRollup` result or the running agent), and anything without evidence is reported as not started.

## Strict status checks and multi-arch images

- **Keep the PR run honest:** the PR run covers the merged code only when the branch is up to date with `main` before it merges. In the branch ruleset add **Require status checks to pass** with the repo's check names and turn on **Require branches to be up to date before merging** (API: the `required_status_checks` rule with `strict_required_status_checks_policy: true`; classic protection: `required_status_checks.strict: true`). The setting only exists alongside required checks. Use GitHub's "Update branch" when a PR falls behind.
- **Required check names:** `PR Checks` replaces `PR Title`, `PR Body`, `PR Hygiene` and `Gitleaks (secret scan)`.
- **No no-op jobs:** the licence check ships per ecosystem, only where a root `go.mod` or `package.json` exists.
- **Prebuilt security tools:** Go Security installs the pinned gosec release binary and checks its SHA-256; govulncheck has no release binaries, so it is built once per version and Go toolchain and cached (the weekly run on `main` keeps the cache warm). Bump either tool in `job-go-security.yaml`.
- **Multi-arch service images:** every service image is one multi-arch manifest list for linux/amd64 and linux/arm64. Each platform builds natively on its own GitHub-hosted runner (`ubuntu-24.04`, `ubuntu-24.04-arm`; no QEMU), pushes by digest, and one small job joins the digests with `docker buildx imagetools create` and checks both platforms are in the list. Images build on a published release (or by hand from a release tag) only, never on pull requests. A repo that signs images signs the manifest list's digest. A new service scaffold carries this as `job-image-publish.yaml`.
