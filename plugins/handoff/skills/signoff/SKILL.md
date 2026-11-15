---
name: signoff
description: Use when building or updating a sign-off checklist page for delivered work (features, fixes, changes): item content, how-to-test steps, order, environment scope, dependencies, jump bar, QA gate.
---

# Sign-off checklists for delivered work

Every review of delivered work (new features, bug fixes, changes) gets a sign-off checklist page on the hand-off site, like the sign-off page of an earlier delivery.

## Items
- One per feature or fix, showing the build/version under test, with Yes / No / Changes / Skipped and Copy results.

## How to test
- Each item's "How to test" steps show inline under the item, collapsed until expanded in place. This holds on every checklist and review page.
- Each step is one action, numbered from 1, never several actions in one step. A step that needs detail gets sub-steps (1.1, 1.2).
- Every step and sub-step has a small checkbox the tester ticks to keep their place, saved with the page for that round. Ticks aren't answers and don't change Yes or No.

## Order
- Items run in logical test order (each builds on the one before: install, setup, sign-in, then features, then update and revert), never by issue number.

## Scope by environment
- Bug fixes are listed only for a new release to QA or prod; in dev they're assumed present.
- New features are listed in every environment.

## Dependencies
- Items declare what they depend on. An item that needs another item answered (Yes, Changes or Accept risk; No or no answer keeps it blocked), or a fix to land, to work shows "Blocked by <id or issue>": greyed, not answerable, not counted as open, and listed as BLOCKED in Copy results.
- When the blocker is fixed, its dependants reopen automatically ("unblocked by #N").

## Jump to open
- Every checklist and review page has a jump bar: Next and Previous open item, the open ids as clickable chips, and the n and p keys.

## QA gates prod
- Where a QA environment exists, nothing is promoted to prod until its QA checklist is signed off (every item Yes or Skipped).
- Hotfixes and emergency builds are the only exceptions.

See `handoff:site` for the shared look, wording and blockers.
