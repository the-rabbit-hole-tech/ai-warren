---
name: board-to-build
description: Use when building or changing a screen that has a board in the project's design Artifact: follow the board faithfully, compare the build with it side by side, have a second reviewer check it, and say so when no board exists.
---

# Board to build

A board in the project's design Artifact is the source for a screen. Executing it faithfully comes first; green tests do not prove a screen matches its board.

- **Find the board first.** Before you build or change a screen, find its board in the project's design Artifact. Read the board's own files (desktop and mobile) and render them at 1440 and 390 wide. Build to match structure, order, states, text, type faces and sizes, not only the idea of the screen.
- **Compare side by side.** Run your build at the same two widths and put a board-versus-built screenshot pair in the PR body. List every difference. A first pass may differ in polish; it never differs in structure, order or states.
- **A second UI reviewer.** A different session or agent from the builder checks the build against the board before the merge. It never reviews its own work. It opens the board and the running screen at both widths itself, does not rely on the builder's pair, and reports every difference it finds, or states that there are none. The merge waits for that report.
- **No board, say so.** If a new screen has no board, say so in the PR and ask for a board before you build it. A small change to an existing screen needs no new board.
- **Expect spot corrections.** The owner reviews the running screens and corrects them as he goes. His note wins over the board. List each override in the PR's difference list so the board is updated afterwards.
- **Never delete or replace** anything in the Artifact: read it first, add to it, and leave existing boards as they are.
- **Report it.** A UI report names the board it followed, shows the pair, lists the differences and names the second reviewer. A report without those goes back.

For a new component or page, see `design:new-ui`; for a visual design session, see `design:design-session`.
