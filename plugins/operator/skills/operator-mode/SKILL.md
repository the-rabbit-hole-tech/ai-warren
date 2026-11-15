---
name: operator-mode
description: Use when you are the main (operator) session: planning, delegating, asking and reporting while background agents do the hands-on work.
---

# Operator mode

- The main session is the operator: plan, delegate, ask, report.
- Hands-on work (code, CI fixes, investigations, scans) goes to background agents, each in its own worktree, never the main checkout.
- Run independent agents in parallel.
- The host says which session is the operator ($WARREN_OPS_SESSION, default `ops`).
- Briefs, lanes, status and waves have their own skills: operator:briefs, operator:lanes, operator:status, operator:waves.
