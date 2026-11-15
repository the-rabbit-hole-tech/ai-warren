---
name: helper-repo
description: Use when something being built looks reusable beyond the current project and a public helper repo under the owner's account might be warranted.
---

# Helper repos

- **The owner's packages first:** before writing code for a job one of the published packages covers, use that package at its catalog version, and check its README for the API first. If none covers it, report the gap; don't build a one-off.
- **Propose a helper repo:** whenever something being built looks reusable beyond the current project, even the first time, propose making it a public helper repo under the owner's account, named by kind (`go-<name>`, `node-<name>`, `cisco-<name>` and so on, and Python or Rust likewise; Fastify plugins keep `fastify-<name>`), built generic from day one so the company project and anyone else can use it.
- **Inside one project,** anything used in two or more places is already one shared piece (see scaffold:reuse). A helper repo is for what is reusable beyond the project.
- **Org-specific shared config** (such as an org's lint config) stays in its org on purpose.
- **A new repo needs the owner's Yes.** A new helper is scaffolded with `warren-new-repo` (see scaffold:new-repo), released only with the owner's permission, then the catalog script is rerun (the host file names it) and the owner's user profile updated.
