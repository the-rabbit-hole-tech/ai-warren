# Releasing

How a release of ai-warren is cut. Only the maintainer tags and publishes.

## Versions

- **The repo release** is one semver, `vX.Y.Z`, set by a git tag. It versions the `warren` CLI
  (the GoReleaser archives) only. Plugins and the marketplace are versioned separately and are not
  part of a release.
- **Each plugin** has its own semver in `plugins/<name>/.claude-plugin/plugin.json`. Bump a plugin
  in the PR that changes it: patch for wording and fixes, minor for a new skill, hook or script,
  major for a breaking change to what it enforces. Claude Code updates a plugin only when its
  version changes, so a changed plugin with an unchanged version never reaches anyone.
- **The marketplace version follows the highest plugin version.**
  `tests/warren/versions.test.sh` fails the PR when `metadata.version` in
  `.claude-plugin/marketplace.json` differs from it. Set it in the PR that bumps a plugin.
- **The first public release is v1.0.0.** The marketplace and every plugin start at 1.0.0; the
  previous repo's tags do not carry over.
- **The tag does not have to match the marketplace or any plugin version.** It numbers the CLI
  binaries and nothing else.
- Org and personal plugins (see the README) carry no version and track their default branch. Only
  this repo's plugins are versioned.

## Cutting a release

1. Merge the PRs for the release. release-drafter has drafted the notes from the PR labels.
2. In one PR, set `metadata.version` in `marketplace.json` to the new version (at least the highest
   plugin version) and bump any plugin whose files changed since the last release.
3. Dry-run the build with `task release:snapshot`. It uses the GoReleaser version the workflow pins
   and writes four archives and the checksums file to `dist/` (git-ignored). It tags and publishes
   nothing.
4. On `main` with green checks, and with the maintainer's explicit Yes, tag the merge commit and
   push the tag (`vX.Y.Z`). Tag rulesets let only the maintainer do this, and a `v*` tag can never
   be moved or deleted.
5. `.github/workflows/release.yaml` builds the four archives (darwin and linux, amd64 and arm64) and
   `warren_<version>_checksums.txt` with GoReleaser (build only) and `scripts/attach-release.sh` uploads them into the
   release that exists for the tag, so a tag has one release. The usual route is to publish release-drafter's draft in
   the browser: that creates the tag, and the workflow adds the archives to that release a few minutes later. If the tag
   was pushed first, the files go into release-drafter's draft; only when no release exists does the script create a
   draft. It never creates a published release, and it never makes a second one.
6. Check the release: the notes, the four archives and the checksums file (and the hand-off web tarball, below). Verify a
   download with `shasum -a 256 -c warren_<version>_checksums.txt`.
7. If the release is still a draft, publish it by hand in the browser. Nothing publishes automatically.

## If something is wrong

A published release is never edited to change its assets and a tag is never moved. Fix forward:
cut the next patch version.

## The hand-off web (adapters/handoff-web)

The hand-off site is part of ai-warren and has no tag of its own. The same `vX.Y.Z` tag that builds the CLI archives also
packs the site: the second job of `.github/workflows/release.yaml` runs `adapters/handoff-web/scripts/build-release.sh`
and attaches `handoff-web-X.Y.Z.tar.gz` and `handoff-web-X.Y.Z.sha256` to the same draft release. Publishing the draft
publishes both.

- Dry-run: `adapters/handoff-web/scripts/build-release.sh X.Y.Z dist` writes the two files from the committed tree. It tags
  and publishes nothing.
- Check the draft for the site's two files as well as the CLI's, and verify with
  `shasum -a 256 -c handoff-web-X.Y.Z.sha256`.
- To update a running site, unpack the tarball and run `install.sh <site-dir>` on it again: the code under `_site/` and
  the template files are replaced, and `site.json`, saved answers, your pages and `custom/` are kept. Restart
  `_site/serve.py` afterwards so the server runs the new code. Back up the site folder first.
