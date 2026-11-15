---
name: review-page
description: Use when building or updating a hand-off review page: Yes/No/Changes items, re-reviews, closing items already answered elsewhere, open questions.
---

# Review pages

## Items
- Every item gets Yes / No / Changes, unless the page sets its own choices (for example the Start/Hold backlog).
- Notes are required for Changes. Answers survive reloads. The page has a progress count and Copy results.
- Nothing on a page is built or merged until every item is Yes.

## Starting data for every step
- Every step a test or review page gives the owner comes with the minimum already-created data needed to start that step: the named record, the user to sign in as, and the starting thread, draft or file to open.
- It is not the full end state: the owner does the action and sees the result. Nothing is left for the owner to find or guess.
- The starting data is created and checked before the page is sent, and a step without it is marked blocked, not sent as open.
- Every step is unique: one distinct action on one record. Where a check applies to more than one kind of record, each kind is its own step with its own prepared record, starting state and steps, unless both kinds run on the same shared component (one component used in both places, no copy, confirmed from the code): then it is one step. Where the kinds draw it with different code they stay separate steps until the component is shared. A step never says repeat on the other, and no two steps on a page repeat the same action text.

## Fixing a round
- While a test round is in its fixing phase, restarting the test servers or resetting the test data needs no question: when a fix needs it, restart them, rebuild the starting data for the steps, and keep the page current (links, build label, reopened and blocked items), then say what changed.
- An item already answered Yes stays Yes through a restart or a reset; only an item whose fix has merged is reopened for a retest, and an item whose fix is not yet on the servers is marked blocked, not open.
- After any restart or reset, run the pre-flight on the page before telling the owner it is ready.

## No unified review pages
- Each review lives only on its own page (design, migration, checklist and so on) and is answered there. Folder indexes link those pages directly.
- There is no `/<folder>/review/` aggregator page.

## Re-reviews show only what's open
- Items already answered Yes stay visible as collapsed, locked history, set from the owner's pasted results and not only browser storage, and kept in Copy results.
- An answered item comes back only if a change alters it, marked Reopened with the reason.

## Never ask twice
- When a sign-off checklist (the real system) answers something a review page also asks, close the review item from that answer: closed as accepted if Yes, or hidden and linked to the filed issue if Changes.
- It reopens only when that fix ships.

## Open questions
- Review and design pages may also carry open-ended questions, as their own item type: a free-text answer box (no Yes / No / Changes), shown with the question, its context and any suggested answer.
- Copy results lists each as "Q <id>: <answer>".
- They are not blockers: no Blocker button, and they don't hold up a page's approval.
- Use one only when the answer isn't a choice. Choices with options still go to AskUserQuestion. Questions are never left as plain text inline on a page.

See `handoff:site` for the shared look and wording.
