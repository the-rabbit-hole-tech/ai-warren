---
name: warren-release
description: Use when the review-or-release menu is picked: ask what to do, then follow the matching GitHub skill.
disable-model-invocation: true
---

# Review or release

Ask with AskUserQuestion, two options:

- **Review PRs waiting on me:** follow github:approve-merge, one question per PR, batched up to 4.
- **Release:** follow github:release. When the owner says "Cut <x> <version>", follow github:release-cut instead.
