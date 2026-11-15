---
name: lang-shell
description: Use when writing shell scripts (*.sh) or running npm ci, npm install or npm pack in a repo.
---

# Shell rules

The global rules come first; this adds Shell detail and never overrides them.

- **Layout:** follow the repo's layout block (defined in your shared rules repo) once the repo has one.
- Scripts keep a `#!/usr/bin/env bash` shebang.
- Always run `npm ci`/`npm install`/`npm pack` with `--ignore-scripts` (husky's `prepare` re-sets `core.hooksPath` and bypasses the global guard).
