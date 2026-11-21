---
name: long-review
description: Use when the owner reviews a whole product over a long session (every page or screen, live) and the work collects on one parent branch with a parent issue, instead of a wave across many repos.
---

# Long review sessions

A long review session is one body of work reviewed live, over hours or days. It is not a wave (many repos at once, one lane per repo, see operator:waves) and not single-issue work (one repo, one issue, see github:work).

## Shape

- One parent branch holds all the work. One parent issue stands for it; every piece of work is a sub-issue of that parent.
- Each sub-issue (or small group of related ones) gets its own branch off the parent, in its own worktree. When the piece is done, its code and all its issues merge into the parent branch, even when it covers more than one issue.
- Nothing is pushed and no PR is opened until the owner says. At the end there is one draft PR from the parent into the default branch, ready when local checks pass, one CI run, then merge. Issues close only when the work reaches the default branch.
- This saves CI minutes, public repos included: one run for the whole session, never one per piece.
- A session that spans repos keeps one parent branch per repo and merges them in contract order (the contract first, then what consumes it).

## Running it

- The owner lists notes as he reviews. Log each one verbatim first, in the session's findings file, numbered by page or screen. Do not fix as he talks.
- Batch related notes into logical groups and code a group once it is complete or he says he is at a point. Say when you start one.
- Look before building: reuse what the project's shared component list holds (the components MCP where there is one), and extend it by prop. A thing used in two places is a shared component.
- Conventions the owner locks go in a locked-conventions file, applied to every later page without asking again.
- Refactors that stop a repeated mistake are part of the session: do them on a branch off the parent, with no visual or behaviour change, and merge them in before the next round.
- A finished round merges to the default branch before the next round starts. The next round's parent branch is cut from the merged default branch, named for the round.

## Roles

- OPS logs, batches and merges into the parent; project work runs in its own coding window on its own worktree (operator:sessions).
- Merging into the parent is local and needs no ask. Pushing, opening the PR, merging it and any release stay the owner's Yes.
