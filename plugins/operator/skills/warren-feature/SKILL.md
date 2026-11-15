---
name: warren-feature
description: Use when starting a feature across API, UI and E2E: issues, contract, session windows, then one linked-PR approval.
disable-model-invocation: true
---

# Start a feature

1. Ask which product and which feature.
2. File the parent issue and its API, UI and E2E sub-issues (see github:file-issue).
3. Write the contract first (the API shape both sides build against) and put it where both windows can read it.
4. Open the `-API` and `-UI` windows for the product (see operator:sessions), one brief each.
5. When both PRs are green, open the `-E2E` window.
6. Ask one linked-PR approval question that names each PR and the merge order, dependency first (see github:approve-merge).
