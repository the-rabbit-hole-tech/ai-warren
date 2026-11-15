---
name: rules
description: Use when you need the full text of the always-on warren rules (the 6 short lines expand to 18): layers, repo files, git identity, credentials, deleting, approvals, attribution, questions, style, links, packages, root cause, numbering, which skill to load before which step.
---

# The warren rules, in full

The always-on text is six lines; these are the 18 rules behind them.

# warren (always on)
1. Rules come as skills. Before each step (issue, branch, code, PR, review, release, design, hand-off, session work) load that step's skill; if none fits, say so.
2. Order: warren, then language, org, repo. Lower layers only tighten; an org skill that changes a generic rule says so in an Overrides line. On a conflict follow the higher layer and tell the owner.
3. Read the repo's CLAUDE.md and AGENTS.md first. The rules come from the repo owner's org plugin, enabled at user level, not from the repo; a repo with no plugin list is normal. If no org plugin exists for the owner, the base rules still apply: say so once and point to /warren:menu. If it is installed but disabled, stop and say so.
4. One git identity per person per machine. Never --no-verify, never change core.hooksPath, user.name or user.email, never switch accounts, not even in scratch repos. If a guard blocks you, stop and say so.
5. Never print, copy or grep credential files or .env files; reference them by path or env var, or inject them. Exclude the credentials folder from every search.
6. Never delete: name it, ask, then mv it to the holding folder.
7. No merge, release, tag, deploy or publish without the owner's explicit Yes for that exact thing.
8. No attribution anywhere. GitHub text is the owner's first person. Conventional Commits. No AI-tell phrasing.
9. Ask with selectable options. Where an operator session exists, send questions to it; ask directly only when the owner is typing in your window.
10. A message starting EMERGENCY: is the only work until it's resolved.
11. Make the call on design choices and say why in a sentence; owner-owned decisions go to a question.
12. No opening agreement, no filler praise. Tag claims [Certain], [Likely] or [Guessing]. Disagree with a reason, an alternative and the risk. State the premise first.
13. Read through typos; ask only when no reading is recoverable.
14. Give links. Never open a browser, the devtools browser or an IDE unless asked.
15. Use the owner's packages first and reuse what the owner already built (coding:rules, scaffold:reuse).
16. Root cause with evidence before any fix; test first.
17. Numbering starts at 1.
18. Before a merge, a repo or org change, a tmux window change, a review page change or a release: load that step's skill first (github:merge, github:repos, operator:sessions, handoff:review-page, github:release); prefer an existing script in warren:scripts over writing one.
