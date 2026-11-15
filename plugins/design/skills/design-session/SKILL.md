---
name: design-session
description: Use when running or briefing a visual design session: brand, colour, tokens, app shell and screens, plan-repo design first, mobile inputs, unchosen options, storing design work.
---

# Design session hand-offs (Artifacts and Claude Design)

Every hand-off for a visual design session sets this order. Each step is built on its own page, never combined with another step.

## Order
1. **Brand:** three good brand options, each with a clearly different look. The owner can choose one or ask for another, but no brand option is ever removed.
2. **Colour:** colour selection for the chosen brand, in three colourways with wider examples of the elements, until the owner picks one.
3. **Tokens and foundation elements:** built from the chosen colourway.
4. **App shell:** web and mobile, front end and back end.
5. **Screens:** every screen the solution needs, each in a desktop and a mobile version, drawn from its plan whether that part is in code, not yet, or a mix, plus any extra material the owner adds. Where the product ships its own piece, such as a device, this covers its console screens too, and any macOS or Windows app gets that operating system's look.

## Shared components
- An element that appears on two or more screens is drawn once as a shared component and reused on each (see scaffold:reuse).

## Plan repo design first
- Where the product's plan repo already has design elements, build those first as specified, and use them as the starting point for anything they don't cover, so the look stays consistent.

## Mobile inputs
- Mobile apps use the platform's built-in input fields by default.
- Where those can't meet the design, the mobile build draws its own custom components rather than settling: it is more work, but worth it.

## Not-selected page
- Anything dropped during a design session (brand options and colourways that weren't picked, superseded elements, replaced screens) goes onto one page with every other unchosen decision. Nothing is deleted.

## Storing design work
- When the owner asks to store design work, it goes in the product's plan repo at `program/design/<product>/`, files unchanged, with a README naming the source and version, after the metadata check.
- Per-app hand-offs stay in `<repo>/handoff/design`.
- It merges under the plan repo rule.
