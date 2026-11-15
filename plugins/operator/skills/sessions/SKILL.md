---
name: sessions
description: Use when opening, messaging, clearing, compacting or restoring operator and coding tmux sessions or windows, or using the tmux scripts.
---

# Sessions (tmux)

- Two tmux sessions: the operator session ($WARREN_OPS_SESSION, default `ops`) and the coding session ($WARREN_CODING_SESSION, default `work`). The operator does deploys, releases, coordination and small one-off tasks itself.
- Sessions message each other directly: the operator gives work to and talks with the coding windows only through SendMessage (find them with ListAgents), never `tmux send-keys`, and the sessions report back the same way. To wait for a session, ask for its one-time idle notice instead of looking at its pane. tmux is only for opening and closing windows and for sending `/clear` and `/compact`.
- Keep session messages short: to save tokens, the operator sends a session only the task, its links and what the session can't already know; it never restates standing rules, which every session loads itself. Background subagent briefs still carry the rules the common rules require. Sessions report back just as briefly (done or blocked, plus links) and don't narrate on their own screen, since the owner is usually not watching. A full rundown happens only when the owner is in that session and types "I am here. Tell me what's up."
- Coding windows stay sorted by name: every project's windows sit together. Any session that opens or closes a window, a lane's server window included, re-sorts them in the same step.
- A task that grows big leaves the operator session for its own window in the coding session, named after the task. The operator closes the windows it opened when their work is done (`tmux kill-window -t <coding session>:<NAME>`).
- Context cleaning: when a coding window's task ends, the operator makes sure its state is on disk (plan notes, issue comments, owner queue), asking the session to write it first if needed, then closes the window. No coding window sits idle without a task, and none is kept open for hours in case it's needed: a new task starts in a fresh session. The operator session is exempt: it stays alive all the time. At about 60% context (`tmux show -pv -t <pane> @claude_ctx`) the operator sends `/compact`. It compacts itself after each wave and at each review window.
- A session that switches to an unrelated task runs `/clear` first. The operator sends `/clear` to a coding window (by `tmux send-keys`) only after its state is saved, and clears itself only when the owner says so.
- Restore: both sessions and every window are saved hourly. After a reboot the owner runs `tmux-restore`, which resumes each Claude pane's conversation. Terminal opens a plain shell; never start or restore tmux unasked.

## Scripts

The plugin's `bin/` holds `tmux-start`, `tmux-stop`, `tmux-save`, `tmux-restore`, `tmux-restart` and `tmux-prefix`. The hook `hooks/tmux-claude-tag.sh` (wired on SessionStart and SessionEnd) tags each pane with its Claude session id so `tmux-restore` can resume it; it exits quietly outside tmux.
