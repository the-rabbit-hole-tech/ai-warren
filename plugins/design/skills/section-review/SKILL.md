---
name: section-review
description: Use when reviewing a design, plan or code one section at a time with the owner, with Yes, No and Preview options per section.
---

# Section-by-section reviews (design, plan and code)

Review one section at a time.

## Order
- Go in the design point of view: purpose, behaviour and interfaces, architecture, data and errors, then the folder and file layout, then testing.
- The layout comes after the design it serves, never first.

## Show, then ask
- Show each section concisely as normal text, never in a question preview, in its own message.
- Ask the question in the next message, because the dialog hides text sent in the same message.

## Options
- One question per section, with three options:
  - **Yes**: accepted, next section.
  - **No**: stop and drop the review. Remove it from memory and plan notes, and move its files to the holding folder (the host file names it).
  - **Preview**: ASCII art of that section, then ask again.
- No ASCII art unless the owner chooses Preview.
- Reworking a section goes through "Other". If the input touches sections already accepted, say which, rework those and take them back through the options.

## Building
- Nothing is built until every section has a Yes.
