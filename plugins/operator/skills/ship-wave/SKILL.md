---
name: ship-wave
description: Use when a lane or coding session works one item of a wave brief end to end: issue, worktree, test first, gate, PR from the template, CI watch, optional browser check, report to OPS.
---

# Ship one wave item

For each item in the brief:

1. File the issue (search first; one issue per PR) with assignee, milestone, label and type (github:work).
2. `git worktree add ../wt-<slug> -b <slug>`; work only there.
3. Write the failing test first, then implement.
4. Run the full gate (lint, typecheck, test) as separate commands.
5. Commit in one call, then push in the next. Never chain them.
6. Read `.github/pull_request_template.md`, then open the PR as a draft with the template filled in (github:work); mark it ready when the work is finished.
7. `gh pr checks <n> --watch` until green, or report the specific failing check.
8. If the item changes UI: with the owner's per-run devtools Yes, navigate, screenshot and evaluate the changed element; without it, give the preview link and report it as not browser-verified.
9. Merge only through the owner's recorded Yes (github:merge: ask OPS with the PR number, then `merge-green.sh`); otherwise leave the PR open.
10. SendMessage to OPS: PR link, CI status, browser-verified yes or no, evidence for every claim.
11. Remove the worktree and the local branch.

Report line for every PR: "Browser-verified: yes/no + what was checked" (no UI change: say so).
