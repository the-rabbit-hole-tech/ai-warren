---
name: repos
description: Use when creating, forking, archiving, retiring or renaming a repo, editing its About fields, or updating an org or user profile README: description, topics, forked and to-be-deleted topics, profile lists.
---

# Repo metadata and profiles

## repo-metadata

- **Every repo created or forked:**
  - Always set a description and topics; never leave a repo without a description. Own repos get the ecosystem base topics (the scaffold applies them) plus domain topics.
  - Forks get the single topic `forked` and nothing else (`gh repo edit <o>/<r> --add-topic forked`, removing any others).
  - Repos slated for deletion get the single topic `to-be-deleted`. Their code, issues and PRs stay untouched, and they're skipped in rollouts, sweeps and reviews. Never delete a repo myself; remind the owner at every review window until each one is gone.
- **Hands-off:** archived repos are never touched (no issues, PRs, labels, topics, README or profile passes, sweeps, rollouts or reviews).

After any repo change, see github:profiles for the profile and About updates.

## profiles

- **Org profile repos** (`<org>/.github`, and `<owner>/<owner>` for the user profile) are part of governance. `profile/README.md` describes the org's project and purpose (what it builds, for whom, how to get involved) and links public repos only. Never name, link or hint at a private repo: no names, counts or "coming soon" teasers.
- **Private org repos** that hold a members-only profile or the org's rules are governance too: they stay private and list private repos only there.
- **When to update:** in the same wave whenever a repo is created, made public, renamed, archived or deleted, or its description changes. Check every profile, the org descriptions and each repo's About fields (description, website link, topics) before reporting done.

## Lessons
- **Update the org and user profiles, repo descriptions, website links and topics in the same wave as any repo change.** That covers repo CREATION (every new PUBLIC repo gets its description, website link, topics and profile entry straight away; private repos are skipped until they go public), renames, archives and public flips. Profiles that are not updated drift: they list old names and miss new repos. After any such change, check every profile and the repo "About" fields before reporting done.
