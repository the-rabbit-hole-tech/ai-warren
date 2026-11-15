---
name: lanes
description: Use when launching, briefing or finishing a worktree lane or background agent: which repo it starts from, what it may delete, and how it cleans up.
---

# Lanes

- Launch a worktree agent from the target repo: cd into the target repo right before every isolation launch.
- A lane runs on Sonnet 5.5 unless its brief names Opus (high reasoning) or Haiku (large text work) in the Agent tool's `model` field (the model rule is in operator:briefs).
- Lanes never `rm`, not even a no-op. Briefs say: no rm of anything outside the lane's own scratch folder; for anything else, name it, ask, then mv it to the holding folder ($WARREN_HOLDING, the host file names it).
- A finished lane deletes its own scratch: when its result is merged or published, it deletes its scratch folder and removes its worktrees and its own docker containers and volumes, in the same step as its final report. `git worktree remove` is never blocked.
- The operator also sweeps finished lanes at every review window. Anything outside the lane's own scratch (the holding folder, other lanes, shared folders) still needs the owner's OK.

## Lessons

- Launch a worktree agent from the target repo so it gets that repo's worktree; one launched from another repo's working directory gets the wrong one.
- Lanes never `rm`, not even a no-op: no `rm -f` on a file the lane made, and no defensive `rm -rf` on a folder that may not exist.
- Finished lanes delete their own scratch so build caches, worktrees and test containers don't fill the disk.
