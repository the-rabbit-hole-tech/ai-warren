---
name: tasks
description: Use when listing tasks or keeping the numbered backlog: "Task X" and "Backlog X" wording, numbering, and the Backlog board.
---

# Tasks and backlog

- Always write tasks as "Task X: <the task>". During multi-step work, show the current task list, keep it updated, and show only what remains.
- Write backlog items as "Backlog X: <item>". Each gets the next number when it is added and keeps it until it is started or dropped. Numbers are never reused or renumbered, so "drop Backlog X" or "start Backlog X" always means the same item. A started item becomes a Task that names its backlog number.
- The Backlog is its own board on the hand-off site (`/backlog`, the page `backlog/board`), not a page of the operator's folder; the operator's folder keeps only hand-offs. It mirrors the numbered backlog. The operator regenerates it with `backlog-page.py` from `backlog.json` whenever an item is added, started or dropped, and reads picks with `backlog-page.py --read`. The host file gives the paths.
- Board rules: Send this item appears only after Start or Hold is pressed (a comment alone cannot be sent). Start means go: read its comment first, then it becomes a Task naming its backlog number. Hold alone means just hold. Hold with a comment means revise the item as the comment says. Drop (with confirm) is final: set the item `dropped` in `backlog.json` and rebuild; it comes back only as a new item. Statuses in `backlog.json` are open, started, done or dropped (never `hold`).
