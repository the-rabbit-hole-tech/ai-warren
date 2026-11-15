---
name: self-learning
description: Use when a mistake repeats or a lesson is recorded, promoted or pruned, or when a rule names a script that is missing on the host.
---

# Self-learning

- Lessons log: the base plugin owns it. It lives only on each machine, in no repo, at `~/.claude/warren/lessons-log.md`, or wherever `WARREN_LESSONS_LOG` points. `warren init` creates it, with a one-line header, when it is missing.
- Entry format: one line per lesson, `- YYYY-MM-DD <skill or step>: <what went wrong and what to do instead>`. Add the second date to the same line when it happens again.
- First occurrence of a mistake: one dated line in the lessons log.
- Second occurrence: a line, with both dates, in the `## Lessons` section of the skill for its step, added through an ai-warren PR (no longer the common file).
- Quarterly pruning: at the first review window of each quarter, a lesson with no recurrence since it was added moves back to the log.
- Lessons are advisory: adding, moving or dropping one needs no confirmation, and any rule beats a lesson.
- Scripts a rule names exist on the host: every script a rule names must exist on the host. A missing one is a setup gap to report, not something to work around.
- Keep the global file lean: new guidance goes to its skill (or a language file), not into an always-loaded file.
