# Adapters

An adapter is a program that serves one of ai-warren's skills and lives under `adapters/<name>/`.
It has its own language, tests, licence file and agent guide, and is built by its own path-filtered
workflow, so the Go CLI and the plugins are not affected by it.

## handoff-web

The hand-off site: a small self-updating review and sign-off site (chips, live updates,
Yes/No/Changes reviews, checklists with blockers) that the `handoff` plugin's skills write pages
for.

- **Where:** `adapters/handoff-web`. It came from Bugs5382/claude-handoff-web with its commit
  history (`git log -- adapters/handoff-web` follows it).
- **Licence:** MIT, `adapters/handoff-web/LICENSE`. The rest of the repository is Apache-2.0; the
  `NOTICE` file records the MIT notice.
- **CI:** `.github/workflows/job-handoff-web.yaml` runs lint, type-check and tests on python 3.9 and
  3.13, and checks that the committed React build matches its source, only when the adapter changes.
- **Releases:** the site has no tag of its own. A `vX.Y.Z` tag makes `.github/workflows/release.yaml` build the CLI
  archives and, in a second job, pack `adapters/handoff-web/scripts/build-release.sh`'s tarball and checksum onto the
  same draft release; the maintainer publishes it by hand. `RELEASING.md` has the steps and how to update a running site
  from the tarball. The repository is public, so a download needs no token (`gh release download`).
- **Pending:** claude-handoff-web PR 146 (inline icon copy button, closes issue 145) is being
  finished in claude-handoff-web. After it merges there it can be carried over with
  `git format-patch` and `git am --directory=adapters/handoff-web`.
