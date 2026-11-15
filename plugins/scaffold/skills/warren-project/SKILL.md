---
name: warren-project
description: Use when the owner runs /scaffold:warren-project to start a new project or repo.
disable-model-invocation: true
---

# Start a new project or repo

1. Ask the owner which org or account the repo belongs to.
2. Ask for the repo name, and confirm it before anything is created (see the naming rules in scaffold:new-repo).
3. Ask for the project type: a `template-<type>-<name>` repo to clone (see scaffold:reuse), or a plain ecosystem and its layout variant (`templates/ecosystems/<eco>/layouts/variants` in this plugin).
4. For a plain ecosystem, run `warren-new-repo <name> <eco> --org <owner> --variant <v> -d "<description>" --dry-run --out <scratch folder>`. Show the owner the settings line, the file list and what a real run would do. If the settings line says `none` for an owner that should have its own values, stop and say which `scaffold/` folder is missing.
5. On the owner's Yes, run the same command without `--dry-run` and `--out`, from the folder the repo should live in.
6. Optional: run `/warren:warren-repo` in the new repo only if it needs its own plugin list or overrides. Most repos need neither.
