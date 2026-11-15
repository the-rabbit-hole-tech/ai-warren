---
name: site
description: Use when publishing to, updating or changing the hand-off site, or building any page for it: folders, shared look, indexes, chips, live updates, wording, blockers, the inbox hook.
---

# The hand-off site

Applies where the host runs a hand-off site. The host file names the site's address and folders; the site folder is in `WARREN_HANDOFF_SITE`. A host without one skips this skill.

Once hand-off v3 ships, the MCP tool descriptions carry these rules, and this skill keeps the when and why.

## The site
- **One server, one port.** No session starts its own web server.
- **Test copy:** the one exception is testing changes to the hand-off site's own repo: a second copy on its own local port, running the PR's code with sample pages only, never touching the live site's pages, inbox or `_site`.
  - Every change to that repo comes with a link to this copy running it, and no approval is asked without the link.
  - The host file names the port when it keeps one.
- **Installed from the public repo:** the site is installed and updated from the site's public repo with its `install.sh`, never rebuilt by hand. The live site only ever runs a published release: once one is cut, it updates to that tag in the same pass, never from main or a PR.
- **Folders:** each session publishes only into its own subfolder. The operator owns the root and `/_site/`.

## Pages
- **Shared look:** every page uses `/_site/site.css`, `/_site/review.js` and `/_site/live.js`; no page carries its own copy. How-to: `/_site/README.md`.
- **Indexes:** each folder lists its pages in its `_status.json` (state needs-you, reference or done, plus a one-line note); `gen-index.py` builds the indexes from it.
  - Indexes show "Needs you", then "Reference", then a collapsed "Completed".
  - Finished pages move to Completed as soon as their item completes, and files are kept.
  - The root shows a "Needs you now" list from every folder.
- **Chips:** cards carry chips: New, Updated, To review, Reopened, Accepted, Reference, Done. A session may add its own, for example "Needs you".
- **Live:** indexes and review pages update themselves; the owner never has to refresh. A review page never reloads while the owner is typing or just after a click, and keeps the answers and scroll position.
- **Links and values can be copied:** every link and address on a page, and every value a step tells the person to type or copy (a name, a password, quoted text, text in code), has a Copy button inline with that step, so the owner can paste it into the browser or field they use. Until the site's renderer draws these, a page puts a `copy` block right under each step.
- **One wording everywhere:**
  - Answers: Yes / No / Changes, unless the page sets its own choices (for example the Start/Hold backlog).
  - Plans add Accept risk; test checklists add Skipped.
  - Item states: Open, Reopened: <reason>, Accepted, Skipped (locked).
  - Buttons: Copy results and Clear my answers.
- **Blockers:** every review and checklist item has a red blocker button for just that item (note and build).
  - "Blocker: send now" when the page sends results to a session, which delivers it at once.
  - "Blocker: copy now" when the page only copies, for the owner to paste to the operator at once.
  - Copy results marks those items "BLOCKER". A pasted blocker goes to the front of the queue.

- **Release website and docs reviews:** after every product release, the website and docs-site review is its own review page on the hand-off site, in that product's folder. The preview builds are copied into that folder and served from the site itself, with no separate local preview servers.

## Inbox hook
- The `handoff` plugin's UserPromptSubmit hook (`hooks/inbox-check.sh`) prints a line when a hand-off Send is unread or nobody is listening. It reads the site folder from `WARREN_HANDOFF_SITE`, picks the session's inbox (`WARREN_HANDOFF_AGENT`, the operator session in `WARREN_OPS_SESSION`, or the inbox named in the working directory) and stays silent when the site is unset or missing. It only prints a line; it never acts.

See `handoff:review-page`, `handoff:phased-plan` and `handoff:signoff` for the page types.
