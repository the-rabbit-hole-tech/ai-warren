---
name: watching
description: Use when waiting on a PR, CI run or long job or build cycle: how often to check, which tool, and when not to look at all.
---

# Watching PRs, CI and long jobs

- Doing the work beats watching it. Check through the GitHub MCP server with long polling: one check, then a long wait sized to the job (about 20 to 30 minutes is typical). No tight polling loops, and no nohup plus a log.
- Until a host has the GitHub MCP server set up, use gh with the same intervals. Checks on PRs, CI and long jobs go through the MCP server once it is set up (its token comes from an env var, never a file).
- Watch actively only during a rollout (a deploy to dev, QA or prod, until it is verified) or an emergency.
- Long build cycles (multi-hour builds, waves or proofs, at any time of day): the coordinating session takes no looks in between (no polling timers, PR, CI or log peeks, or status reads; every look costs tokens). It acts only on a lane's final report, a lane's blocker report, or a single timer for a step it must start itself (for example a 03:00 build go).
- Lane briefs say: report once at the end, or immediately for a blocker, never per merge or milestone. Routine news goes into the end-of-cycle summary, not relayed.
