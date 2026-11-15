---
name: new-repo
description: Use when creating a new repo or naming one: governance before first content, warren-new-repo, repo name prefixes, multi-arch images for products.
---

# New repo

## Setup
- **Governance first, no exceptions, even when moving fast:** before a new repo's first content commit, it gets the full shared governance for its type: the structure, the Claude settings, templates, labels, the full GitHub workflow set and the rulesets with required checks. Only then does product content land, through PRs the checks gate.
- **Create it with `warren-new-repo <name> <ecosystem> --org <owner>`** (this plugin's `bin/`, on the Bash tool's PATH). Ecosystems: action, claude-code, fastify, go, npm, python, storybook, swift, vite (rust has layouts only). `--variant` picks the layout, `--private` the visibility and private overlays, `-d` the description.
  - Run it with `--dry-run --out <scratch folder>` first and show the person the file list and what a real run would do. The dry run makes no git repo and calls nothing on GitHub.
  - A real run commits, creates the GitHub repo, pushes, applies the ruleset (`warren-apply-ruleset`) and the ecosystem topics (`warren-apply-topics`). It runs only after the person's Yes on the name and owner.
  - An existing empty GitHub repo: `--existing`. Local only: `--no-remote`.
  - Optional afterwards: if the repo needs its own plugin list or overrides, write `.claude/settings.json` with `/warren:warren-repo`. Most repos need neither.
- **The owner's values** (copyright holder, licence, operator, DCO, CODEOWNERS, ruleset, skip list, starting files, release-drafter config) come from the owner's `scaffold/` folder in its org or personal plugin. The dry run's first line says which folder it used; `none` means the generic defaults, so check that before a real run. The plugin README lists every setting.
- release-drafter-action handles first releases; there is no first-release prep step.

## Naming
- A name starts with what the repo is (`go-`, `node-`, `helm-`, `config-`, `claude-`, `cisco-` and so on). `ai-` is a recognised prefix for AI agent tooling.
- Template and starter repos that other repos are built from start with `template-` (`template-go-service`, `template-docs-site`).
- The prefixes are examples, not a closed list, and the name is confirmed with the owner before any repo is created.

## Multi-arch images
- Every product's first build or release, and every new project, publishes all of its service images to the registry as multi-arch images (linux/amd64 and linux/arm64), so each runs on arm64 hosts as well. Images only inside a bundled image, or amd64 only, don't count. `warren-new-repo` adds `job-image-publish.yaml` to the service variants; the org plugin may list which products are required first.

See scaffold:governance for the governance scope, and scaffold:reuse before building anything new.
