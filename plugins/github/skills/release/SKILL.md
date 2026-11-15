---
name: release
description: Use when asked to release, tag or publish a repo or package, cut a multi-repo product, track a release candidate, or release ai-warren itself: the release ask and proof, notes format, Cut trigger, milestones, RC tracking.
---

# Releases

## release

- Nothing tags automatically; releases are published by hand.
- **A release or tag only on the owner's Yes for that exact release.** Ask with AskUserQuestion, naming the repo, the exact tag (plus any moving major tag like `v1`), the release notes that will publish, and the proof that it has no known issues:
  - no open bug issues against what ships, and CI green on the tagged commit;
  - release-drafter notes in the exact format: the category headings with their emoji titles, entries shaped `<title> @<author> (#N)`, and the Full Changelog compare link. Nothing stray: no release-drafter warning banners (such as the v7 first-release block), no uncategorized `ci:` or skip-changelog items, no hand-written summary lines;
  - the notes match `CHANGELOG.md` only where the repo keeps one (usually npm packages). Go packages and others don't, so their release notes are the changelog;
  - every issue and PR in the notes is on that release's milestone, with nothing open left on it (close the milestone once the release is published);
  - gorelease or semver checks agree with the bump, and for npm the pack size, file list and ESM/CJS install check pass.
  - **Options:** **Release** (publish the draft, which creates the tag, and move any major tag), **No** (leave it and take notes) or **Open browser to review** (open the draft release page, then ask again). Batch up to 4. A Release answer covers only that tag. A host file may add a tighter gate.
- **Marketplace actions** (changelog-updater-action, typedoc-pages-action, release-drafter-action and the like) are never published by Claude, even with a Release answer. Prepare the draft, the notes and the major-tag commands, then ask with exactly two options: **Open Browser** (open the draft release page so the owner can publish there with the Marketplace checkbox) or **Wait**. The `marketplace-release-guard.sh` PreToolUse hook blocks release creation and draft publishing in those repos.
- **npm releases:** after a release is published, follow the publish workflow run with long polling, then confirm the new version on the registry (`npm view <pkg> version dist.fileCount dist.unpackedSize`) with the expected size. Report success, or the failure with its log.
- **Unreleased work:** at every review window, and whenever a merge adds to it, list what's merged but not released in each package: draft GitHub Releases, open release-please PRs and commits since the last published tag (the host file names the script that prints it). Each release still needs its own ask.
- **Website prep after a release:** once a product release is confirmed published, prep the update for that product's website and its standalone documentation website (docs not embedded in the application) without being asked, in the same pass. Neither goes live before the owner's manual review, every time.
- **Repos not published to a registry** get release-drafter only (publishing the draft is the tag), with no version-bump commit and no publish workflow.
- **One release-drafter action everywhere:** a repo still on upstream release-drafter, or on an old pin, switches to the release-drafter action your shared rules repo pins, by SHA at its version. Do it on the repo's next pass or before its first release, inside that wave's PR, never as a sweep. When the action has a new release, bump the hub's pins first.

For a multi-repo product or the Cut trigger, see github:release-cut; for release candidates, see github:release-tracking.

## release-cut

- **The Cut trigger:** when the owner says "Cut <product or repo> <version>", take it from there with no asks: pins, the merges that release needs, the freeze, checks, independent review, final notes and one sign-off page.
  - The owner then does two things: sign off, which is the Release answer, and approve signing on GitHub where a repo has it.
  - Anything failed or unexpected stops the run and goes to the owner. Nothing publishes before sign-off. Marketplace actions keep their browser-only publish (see github:release).
  - Cut replaces the per-PR Yes for that release's own PRs only.
- **The runbook goes on the release's tracker issue:** each release's runbook (order, exact commits, checks, publish commands, what to watch, and what to do on failure) is posted as a comment on that release's tracker issue (the "Release vX.Y.Z-rc.N" parent, or the version's own release issue) before the sign-off ask.
  - It's public GitHub text: the owner's voice, no home paths, no real host names, no links to local notes, and no history comparing it with earlier releases.
  - The copy on disk stays as the working copy.
- **Multi-repo product releases (not proven yet, written ahead of rc.6: tags behind main, the proof job, and the hotfix and dependency parts haven't run):**
  - **Pins first:** the release repo pins each service commit, then the product repo pins the release and web commits. The pins are the source of truth; tags are records.
  - **Check first:** compare the runbook with how the last release really ran, have an independent review check it, and check what's currently latest and rc on each repo; the newest tag isn't always the current one.
  - **One ask:** one Release answer covers the set, shown on one page with the channel (rc or latest) and each repo's tag, commit and notes. For multi-repo releases this replaces "a Release answer covers only that tag".
  - **Unchanged repos:** at the start of every Cut, check each repo for commits since its last published tag. A repo with none gets no new tag and no draft; its pin stays at that tag, and the sign-off page lists it as "unchanged, stays at <tag>".
  - **Publish:** no merges to those repos from the ask until done. Publish each draft, never a hand-pushed tag, with each tag on its pinned commit, each draft re-read right before it publishes, and prerelease and latest set explicitly. The product repo goes last, because its tag starts the build.
  - **Hotfix or cherry-picked security release:** only when the owner names one; rcs otherwise roll forward. It branches from the published tag as `hotfix/x.y.z`, changes only the repos it needs, re-pins those commits and gets a new version. The fix also goes to main and any next-version parent branch, and the ask lists those.
  - **Dependencies:** release work pins published versions only, never a branch or pseudo-version. Each rc lists what it needs that isn't released. When a dependency isn't ready, cut a pre-release of it to pin, or move the item to the next rc.

## release-tracking

Release candidates are parent issues, never milestones.

- Milestones are versions only (v0.1.0, v0.2.0, vNext).
- Each release candidate has ONE overall parent issue, "Release vX.Y.Z-rc.N", on its version's milestone.
  - When its work fits GitHub's 100 sub-issue cap, every piece of work is a direct sub-issue of the overall parent.
  - When it doesn't, the overall parent holds numbered child parents, "Release vX.Y.Z-rc.N #1", "#2" and so on, each with up to 100 work issues, until all of it is listed.
- Work already under an open epic keeps that parent (an issue has only one). No checklists go in release issue bodies.
- In a multi-repo product the parents live in the product's release-train repo, with sub-issues from any repo in the org.
- Each parent closes when all of its sub-issues are closed or moved and the rc is published.

## Release Manager, Action repos and first release

- **Release Manager:** on every push to `main` the Release Manager workflow (`job-version-bump.yaml`) lets release-drafter anticipate the next version, bumps the manifest version (package ecosystems only; npm uses `npm version "v<resolved>" --no-git-tag-version --allow-same-version`, Python bumps `pyproject.toml`, Go and Action repos have no manifest), updates `CHANGELOG.md` through the changelog action and pushes a `chore(pre-release): vX [skip ci]` commit. Nothing tags automatically. It pushes through the release GitHub App, which the branch ruleset lists as a bypass actor; without that bypass the `[skip ci]` commit is rejected.
- **GitHub Action repos** have no package manifest and are not published to a registry. The maintainer tags `vX.Y.Z`, publishes the GitHub Release and repoints the floating major tag `vN` (`git tag -fa v1 -m "v1 -> v1.2.3" v1.2.3`, then force-push that tag); the Marketplace listing is an optional manual step.
- **First release is `v1.0.0`:** the pinned release-drafter action resolves a first release (no earlier published release, no `version`, `tag` or `name` override) to `v1.0.0` on its own, listing every merged PR with no "No changes" line and no warning block. Package repos publish the manifest version, so the Release Manager bumps `package.json` or `pyproject.toml` to `1.0.0` from the first releasable push. Go packages have no `CHANGELOG.md`: the release notes are the changelog, so read the draft before publishing.
- **Docs site gotchas:** a tag-gated GitHub Pages deploy fails at the Deploy step unless the auto-created `github-pages` environment allows tag refs: once, with Pages enabled (Source = GitHub Actions), add a tag policy (`gh api -X POST repos/<owner>/<repo>/environments/github-pages/deployment-branch-policies -f name='v*' -f type=tag`) and re-run the failed Deploy job. Docusaurus MDX 3: avoid `## Heading {#custom-id}`; rely on the generated slugs.
