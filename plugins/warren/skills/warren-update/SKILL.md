---
name: warren-update
description: Use when updating ai-warren on this machine, from the warren menu's "Update warren".
disable-model-invocation: true
---

# Update warren

Refreshes the ai-warren marketplace and updates every installed ai-warren plugin that is behind it, in
every scope it's installed in, through `warren step update`. It never installs a plugin that wasn't
installed, and never changes the guard identity.

1. Check first: `printf '{"version":1}' | warren step update --check --answers -`. Report the status:
   `ok` (current as of the last refresh), `drift` (the message lists what's behind).
2. Ask Yes or No, then run `printf '{"version":1}' | warren step update --answers -` and report the
   JSON result.
3. Say the updates load after `/reload-plugins` or a restart. The guard hooks are copied again at the
   next session start.
4. Then run `warren doctor` and report anything that isn't `ok` or `skipped`.

If `warren` isn't on PATH, say so and point at `docs/warren-cli.md` in ai-warren.
