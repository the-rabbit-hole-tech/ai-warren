---
name: governance
description: Use when a change touches repo governance (layouts, labels, workflows, rulesets, milestones, profile rules, Claude config, templates) or when a repo's governance conventions need checking.
---

# Governance

- **Source of truth:** this plugin's `templates/` (the shared governance and the ecosystem templates) and `bin/` scripts define how a governed repo is set up. The owner's `scaffold/` folder in its org or personal plugin adds that owner's own values on top.
- **Where a repo's rules live:** in its GitHub owner's org plugin (a plugin named `warren-<anything>` in a marketplace named for the owner), enabled at user level, never inside the repo. The repo's own `.claude/settings.json` holds only that repo's overrides or tracking metadata (such as the template it syncs from), and most repos have none. A repo without a plugin list is not "not set up"; the real gap is the owner's plugin being missing.
- **Scope:** the shared governance (layouts, labels, workflows, rulesets, milestones, profile rules) applies to the repos the owner works under. The ecosystem templates may still be used as a starting point anywhere.
- **Drift is checked on each pass:** when a repo is worked on, compare it with a fresh `warren-apply-governance --sync` on its branch. Any drift is fixed in that repo's own PR; nothing pushes it from outside.
- **Shared governance changes go to ai-warren:** a change to the shared set made during project work is its own ai-warren PR in the same wave, referenced from the repo's PR. Generic only: owner values go to the owner's plugin.
- **An org's own rules are the exception:** a change to them (including its `scaffold/` folder) goes to the repo that holds that org's rules as its own PR and needs the owner's Yes.

For a new repo see scaffold:new-repo. For an existing repo see scaffold:adopt-repo.
