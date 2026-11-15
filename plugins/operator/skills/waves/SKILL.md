---
name: waves
description: Use when planning or running a wave of parallel lanes, preparing a review window, or applying a new standard to work in flight.
---

# Review windows and waves

- Review windows: twice a day, at the times the host file names. Have a wave's batch finished and waiting at each one.
- Work in waves: file or confirm a wave of issues, run agents on all of them in parallel (one lane per repo), and come back when the wave's PRs are ready.
- Ask for approvals in one batch (up to 4 per prompt), merge the ones that got a Yes in order, then start the next wave. Interrupt mid-wave only for a real blocker.
- Sequence dependent work (a release tag, a contract change, a PR that needs another merged first) and say what waits on what.
- New standards apply to work in flight and to the next pass over each repo. Never run a separate sweep just to retrofit a rule.
- Every PR in a wave report carries the line "Browser-verified: yes/no + what was checked". The devtools browser opens only with the owner's per-run Yes (see the host file); without it the answer is "no" plus the preview link.
- When `WARREN_WORK_HISTORY_REPO` is set and a milestone finishes in a project the host records, queue one low-priority work-history lane for it, never ahead of project work; the org plugin's work-history skill says how.

## Work order

- Order: blocker issues first, then PR approvals, then regular issues. A blocker is any issue or PR that other work or a release waits on. Do a lot in parallel, but a lane that is stuck on a blocker does the blocker first, and a blocker that pops up mid-wave is done at once.
- Blockers that only the owner can clear (a registry or ruleset setting, an admin merge, an account step) go to the owner first and loudest, with the exact step.
- Bring finished PRs to the owner for approval, batches of four, before starting regular issues.
- Fixes before features: finish the open fix issues first, because open fixes limit features.
