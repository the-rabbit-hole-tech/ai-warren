# action (partial stub)

Ecosystem for **GitHub Action** repos — a composite or JS action published by a `action.yml` at the
repo root, consumed by other workflows as `owner/repo@vN`. There is **no package manifest** and
**no npm/PyPI publish**; an action releases differently from every other ecosystem (see below).

Only the release flow is standardized so far. `template/` currently ships just the Release Manager
workflow (`.github/workflows/job-version-bump.yaml`); fill in the rest of the template
(`action.yml`, the composite/JS entrypoint, a smoke test, the test/lint workflows) following the same
model as the other ecosystems when a concrete action setup is ready. New action repos come from
`scaffold/new-repo.sh <name> action`, like every other ecosystem. The shared governance layer
(hooks, GitHub templates, gitleaks, release-drafter config) composes in automatically.

## Release Manager

`template/.github/workflows/job-version-bump.yaml` is the same Release Manager the package
ecosystems use, **minus the version bump** — an action has no manifest to bump. On every push to
`main` it anticipates the next version with the release-drafter action, writes `CHANGELOG.md` via
the changelog action, and pushes a `chore(pre-release): vX [skip ci]` commit. Nothing
tags automatically.

## How a GitHub Action releases (manual)

An action does **not** publish a package. Releasing is a manual sequence the maintainer runs after
the Release Manager has prepped `CHANGELOG.md` on `main`:

1. **Tag the exact version.** Create and push an annotated tag `vX.Y.Z` on `main`.
2. **Publish the GitHub Release** for that tag, with the finalized changelog notes.
3. **Repoint the floating major tag `@vN`.** Consumers pin `owner/repo@vN` (e.g. `@v1`); move that
   tag to the new `vX.Y.Z` commit so they pick up the release:
   ```bash
   git tag -fa v1 -m "v1 -> v1.2.3" v1.2.3
   git push origin v1 --force
   ```
4. **(Optional) Publish to the GitHub Marketplace** from the Release page — manual, one checkbox.

The **first release drafts as `v1.0.0`** on its own — the release-drafter action resolves a
first release (no earlier published release) to `v1.0.0` with full notes and no warning block, so
the maintainer only tags and publishes it, then points `@v1` at it (step 3). Subsequent releases
follow the resolved version normally.
