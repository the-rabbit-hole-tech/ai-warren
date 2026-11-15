---
name: rules
description: Use when working in a repo owned by __OWNER__ and you need the owner's own rules on top of the warren base: replace this text with when your rules apply.
---

# __OWNER__ rules

This is an example. Replace it with the rules that are yours. Each skill covers one step (a commit,
a PR, a release, a README) and says when to load it in its `description`, which must start with
"Use when".

- Write each rule as a short instruction.
- Order of layers: warren (the base), then the language, then this org plugin, then the repo. A
  lower layer only tightens. When a rule here changes a base rule, say so in an Overrides line.

Overrides: none. (Example of a real line: `Overrides: github:open-pr, drafts are not required for docs-only PRs.`)
