A GitHub Action that workflows call from a `uses:` line naming this repo and its major version tag:
composite, or a container built from code in the repo.

### Tree

```text
.
├── action.yml            the action's interface: inputs, outputs, runs
├── scripts/              shell or Node steps a composite action calls
│   └── <step>.sh
├── cmd/action/           container actions: the entry point (Go shown)
│   └── main.go
├── internal/             container actions: the logic the entry point calls
├── Dockerfile            container actions only
├── examples/             workflow files that show real usage
│   └── <use-case>.yml
├── testdata/             fixtures for the self-test workflow
├── .github/workflows/    this repo's CI, including a job that runs the action on itself
├── CHANGELOG.md          written by the Release Manager
└── README.md             inputs, outputs and a copy-paste usage block
```

### What goes where

- `action.yml`: the only file consumers depend on. Every input has a `description` and, when
  optional, a `default`; every output is documented in the README.
- `scripts/`: logic too long to read inline in `action.yml`. Steps call them with
  `${{ github.action_path }}/scripts/<step>.sh`, never a path relative to the caller's checkout.
- `cmd/action/` and `internal/`: a container action's code, laid out like a Go CLI. The image
  reads inputs from `INPUT_<NAME>` variables and writes outputs to `$GITHUB_OUTPUT`.
- `examples/`: complete workflows that the README links to. Not run by this repo's CI.
- No package manifest to publish: releases are tags (`vX.Y.Z` plus the moving `vN`).

### Naming

- The repo is named `<verb>-<thing>-action`; the `name:` in `action.yml` is its title-case form.
- Inputs and outputs are `kebab-case` (`config-file`, `release-tag`).
- Scripts are `kebab-case.sh` with a `#!/usr/bin/env bash` shebang and `set -euo pipefail`.

### Tests, fixtures and generated code

- A self-test workflow in `.github/workflows/` runs the action from the PR's own checkout
  (`uses: ./`) against fixtures in `testdata/` and checks its outputs.
- Unit tests for scripts or container code sit next to the code (`<file>_test.go`, or a `test/`
  folder of shell tests).
- A JavaScript action commits its bundled `dist/index.js`, rebuilt by a script and checked in CI;
  nothing else under `dist/` is edited by hand.
