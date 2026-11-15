---
name: briefs
description: Use when writing the brief or description for a background agent or lane: how to name it and which scratch folder it gets.
---

# Agent briefs

- Agent descriptions start with the full repo: `<owner>/<repo>: <task>`.
- Every agent brief names a lane-only scratch folder (the host says where, inside the session scratchpad), never the shared scratchpad root. Parallel agents once overwrote each other's files there.
- Model: all models are 5.5. Sessions, subagents and lanes run on Sonnet 5.5 by default; the host sets `CLAUDE_CODE_SUBAGENT_MODEL=sonnet`. Opus 5.5 is for high-reasoning work only, and Haiku 5.5 is for large text work (reading, searching or summarising big files or logs, bulk edits, grep-and-report). A brief names a non-default model in the Agent tool's `model` field (`sonnet`, `opus` or `haiku`) and gives the reason.
- Briefs for lanes also carry the lane rules in operator:lanes.
