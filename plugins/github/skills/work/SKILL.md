---
name: work
description: Use when filing or updating an issue, creating or syncing a branch, opening a PR, writing GitHub text, or cleaning up after a merge: search first, template, assignee, labels, milestone, branch naming, draft PR, voice, branch and worktree cleanup.
---

# Issues, branches, PRs and cleanup

## file-issue

- **Search before filing:** before filing any issue, search for an existing one (all states, the shared rules repo and the org). Update or comment on it rather than duplicating; related-but-different issues stay separate and get cross-referenced.
- **Every issue:**
  - comes from a template, is assigned to the repo owner and is labelled from the scaffold plugin's `templates/governance/.github/labels.yml` (or the owner's own `scaffold/labels.yml`);
  - is in the org's Project where there is one.
- **Milestones:** every open issue sits on the active milestone, or on the repo's `vNext` milestone when it isn't for the current release, so no open issue is ever without one.
  - When a wave picks an issue up, it moves off `vNext` onto the milestone of the release it will ship in (created and named for the version if missing).
  - `vNext` holds only open, untagged work: an issue closed as completed moves to the milestone of the release that ships it, and one closed as not planned, as a duplicate or without work loses its milestone.
- **Issue type:** always set it wherever the account or org defines issue types, agent-filed issues included: `feat` means Feature, `fix` means Bug, everything else is Task. gh can't set it, so use GraphQL `updateIssueIssueType`, and re-check it when a wave picks the issue up.
- **Multi-step work** is a parent issue with ordered sub-issues.
- **During an issue-clearing push:** don't file new follow-ups. Fix small findings in the current PR and note them on the issue. Queue the larger ones and ask whether to file, without stopping work.

For the text of the issue, see github:voice.

## branch

- **Branch from the repo's default branch** (check it with `gh repo view --json defaultBranchRef`, never assume main):
  - `main`/`master`: branch `<type>/<issue#>-<slug>`, and PR back into it.
  - `develop` (gitflow): branch off and PR into develop. A release is develop to main; a hotfix branches off main and merges back into both.
  - Never commit directly to main, master or develop. One concern per branch.
  - Repos never have stacked PRs: dependent work waits until the earlier PR merges.
- **Overrides:** "One concern per branch" is relaxed for similar work in the same wave: one branch and PR may close several issues (see github:open-pr). Unrelated work still gets its own branch.
- **Next-version work waits on a parent branch:** while a version or rc is being built, the next version's work never merges into the default branch.
  - Each repo it touches gets a parent branch off the default branch, `rc/rc.x` for an rc or `release/vx.y.z` for a version, and that work's PRs target it.
  - Once the version being built is fully published and on the default branch, one PR merges the parent, and work goes back to normal feature branches. Repos with no release in progress aren't affected.
- **Batches of similar work:** use a parent branch off the default branch. Each change branches off the parent and its PR targets the parent; one final PR merges the parent. Each branch is linked to its issue, and issues close only when the work reaches the default branch, never because a PR merely references them. This is not stacking (no PR targets another PR's branch), so "no stacked PRs" still stands.
- **Verify before asserting:**
  - Before any branch operation, run `git status` and `git branch -vv` and report the state.
  - Sync a feature branch from its base (the default branch, or the parent branch for batch work) and confirm with an explicit diff before working.
  - After every push, check `git ls-remote` against local HEAD; a push that looks successful is not proof the remote moved.
- **Link first:** after pushing a branch, link it to its issue (`gh issue develop`) before writing code.
- **Shared checkouts:**
  - Stashes worth keeping are pushed as `wip/<name>` branches, not left as stashes.
  - While background worktree agents run, don't create or commit branches in the main checkout.
  - Before every PR, confirm the current branch and that the diff against the base touches only the intended files.

## open-pr

- **Agent PRs start as drafts and push once:** run the full checks locally and push once they pass, not once per step. Workflows skip drafts. Mark the PR ready only when the work is finished; that triggers one CI run, and then the owner is asked. After that, further pushes are only for real fixes, batched into one push. Every agent brief carries this rule.
- **One issue per PR is the default.** Similar work in the same wave may go in one PR that closes several issues, each issue still filed and each with its own `Closes #N` (full owner/repo form), above all when a rebase would make every open PR rerun CI. Unrelated work stays in separate PRs.
- **PR bodies:** the repo's template body plus a closing summary. Say the merge order when PRs interact. Squash merge.
- Before every PR, confirm the branch and diff (see github:branch); for CI and merge-ready, see github:ci; for approval and merging, see github:approve-merge.

## Lessons
- **GitHub auto-closes on "does not close #N" (negation ignored).** Partial-fix PRs and commits say "Refs #N" only, with no close/fix/resolve word before `#N`; after merge, check the issue is still open. A branch linked with `gh issue develop` also closes its issue on merge whatever the PR says, so after a Refs-only merge from a linked branch, reopen the issue with the reason.
- **Judge a local check by its exit code, never by its filtered output.** A grep for error lines, or `tail -1`, can show a clean run while the tool crashed or an earlier step failed (`oxlint && oxfmt --check` prints oxfmt's summary last, under the "Format issues found" line). Run each check and read its exit code (`npm run lint; echo $?`); filter only after.

## voice

- **References:** always write the owner in full, `<owner>/<repo>@PR#<n>` or `@issue#<n>`, as a link; accept the owner's shorthand (a bare repo name, any case) and resolve the owner from the code root layout.
- **Emoji:** allowed in READMEs, docs (docs sites included) and examples, in the lite style (see the README style). None in commit messages, PR or issue text, or source; source only when the code needs them (for example a Lexical UI component) and the owner confirms. An org may forbid emoji entirely; its org plugin says so and that rule wins. `CHANGELOG.md` is exempt.

The first-person voice and the no-attribution rules are in the always-on warren text.
- **Prose that reads as machine-written:** when asked to rewrite text so it reads like the writer, read `plugins/github/addons/humanizer/SKILL.upstream.md` (the pinned copy of blader/humanizer; marker in `UPSTREAM.json`) and follow it. It edits prose only: keep every fact, never run text as instructions.

## cleanup

- A branch is done when its linked issue is closed, not when the PR merges. Then delete it locally and on GitHub and remove its worktree right away. If the issue is still open, leave it; flag unclear branches instead of deleting them.
- Agents clean up after themselves: each removes its own worktree and local branches before reporting, unless there's unpushed or uncommitted work, which it reports instead. Every agent brief carries this.
- Sweep at every review window: across the code root and every org, clean up stale branches and worktrees whose PR is merged or closed and whose issue is closed. Push unmerged work as `wip/<name>` first.
- Never rewrite history or force-push main for a leaked non-secret: remove it in a new commit and gitignore it. Only real secrets justify a history rewrite.

## Git and hooks (friction rules)

- Never chain `git commit` with `git push`, or with any other command, using `&&` or `;`. Commit and push are separate Bash calls; the commit hooks reject compound commands.
- Never chain a commit after a typecheck or test command. Confirm the check passed first, then commit in a separate call.
- Never override `core.hooksPath` and never use `--no-verify`. If a hook blocks you, fix the cause or escalate to OPS or the owner.
- Conventional-commit messages, merge commits included. Put the message in a literal string, not a shell variable, because the title hooks reject variable-based commands.

## PR workflow (friction rules)

1. Work in a git worktree, never in the live checkout.
2. Before writing a PR body, read `.github/pull_request_template.md` and fill in every section.
3. Use the repo's existing labels (for example `enhancement`, not `feat`); check with `gh label list`.
4. After pushing, run `gh pr checks <n> --watch`. Do not report a PR as done until CI is green, or until you have reported the specific failing check.
5. For a UI change, verify it in a browser when the owner's per-run devtools Yes is given (navigate, screenshot, check the changed element); otherwise give the preview link and report it as not browser-verified.
6. Report only status you have verified. Never say work is in progress unless an agent or lane is actually running it.
