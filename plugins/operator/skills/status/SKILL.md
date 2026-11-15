---
name: status
description: Use when reporting progress while agents or lanes are running: the Agents running table every status update carries.
---

# Status updates

- Status updates include an "Agents running" table with columns agent, type, task, state and model.
- The agent column names the agent itself: a session's window name, or the repo a helper works in. Never a generic label such as "helper".
- The type column is the agent's role: Helper (a background subagent), Session (a window in the coding session) or Workflow (a multi-agent run).
- The model column names the model each lane or agent runs on (Opus, Sonnet or Haiku, with the version where it matters).
- Every session uses the table when it reports lanes.

## Status table with evidence

- When reporting a wave or a batch of work, give a status table with one row per PR and issue.
- Each row carries its evidence: the `gh pr view --json state,statusCheckRollup` result, or the ID of the agent currently working on it.
- Anything without evidence is marked NOT STARTED. Never write in progress for work no agent or lane is running.
- Every row in the Agents running table and the status table carries a number. The number is stable (the same item keeps it across reports), counts up from 1, and is never reused, like the numbered backlog; a new item gets the next number, and a finished item keeps its number.
- Open work also carries an Order column: the sequence the operator is following (1 is what runs now; "waits" for something scheduled). The owner can reorder it by number ("move 9 before 3"). Finished items drop out of the order and keep their number.
