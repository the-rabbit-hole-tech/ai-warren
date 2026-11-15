---
name: rules
description: Use when making code changes or writing code: surgical diffs, test first, docs in the same PR, logging levels, health checks, READMEs and changelogs, published packages first, porting code, exact UI nudges.
---

# Coding rules

## discipline

- **Surgical changes only.** Every changed line traces to the request or to a standing rule it triggers (docs, tests, logging). Match the existing style.
- **Comments:** default to none. Add one only when the WHY is non-obvious; never explain WHAT, and never reference the task or ticket. Public API doc comments are docs.
- **Error handling:** no handling for impossible cases. Trust internal contracts, and validate only at system boundaries (user input, API responses, file reads). Don't wrap internal calls in try/catch unless they actually throw.
- **Dependencies:** don't add a dependency for a few lines of code, or when an existing one covers it (the owner's packages first, see coding:packages). If you must add one, say why in the PR.

## test-first

- **Test first, every task:** write or identify the test that specifies the behaviour, watch it fail for the right reason, implement to green, then refactor. Agents write most of the code, and the failing test is the spec they can verify against. Exempt: pure mechanical edits with no behaviour change (renames, formatting, comments, config value bumps).
- **Existing tests:** never modify one unless the change intentionally updates the behaviour it covers.
- **A failing test means your change is wrong,** not the test. Fix the code.
- **Removing a test:** only after confirming its functionality was removed, in the same PR, and name it there.
- **Coverage:** every business rule and API endpoint, tested through public APIs, not internals; a refactor shouldn't break a test.
- **A mock server is not a test:** a mock of a backend or gateway is for local runs and walkthroughs only. Every repo keeps its own unit tests against its public API, and passing against a mock server doesn't count as tested.
- **No mocking third-party code:** wrap it behind your own interface and fake that, or test the real thing at the boundary (containers for Postgres, Redis, RabbitMQ).

## docs

- **Docs ship with every PR:** each PR updates the repo's own docs as part of the change.
  - **What to check:** which docs the repo has first (README, a docs site, examples, AGENTS.md, doc comments); many have only a README.
  - **What counts:** anything that adds, removes or changes behaviour, APIs, config, flags or setup updates those docs in the same PR. No separate docs PRs unless the owner asks.
  - **Skipping:** the owner may say to skip docs while the code is still in flux. The docs are then done before the work counts as finished.
  - **Done means:** the docs match the change, the site builds where there is one, and the examples compile. Agent briefs carry this rule.
- **Docs are tested like code:** numbered steps start at 1 (never "0."), and prerequisites go in an unnumbered "Before you start" section. Every command block in an install or how-to doc is actually run, in a clean environment (a fresh clone, container or VM), before the PR is marked ready, and the PR says so. A doc whose commands haven't been run isn't done.

## logging

- **Log generously (all repos and services):** log entry and exit of significant operations, decisions and branches taken, retries, state transitions, external calls (target, duration, outcome), and every error with its context. Use the level to control volume: `trace` for step-by-step detail and values, `debug` for flow, `info` for lifecycle, `warn` and `error` for problems. Too much is fine, because the environment level filters it. Never log secrets, tokens or PHI (MRNs, names and so on), even at `trace`: log an opaque or keyed ID instead.
- **Log levels by environment:** local dev = `trace`; dev cluster = `debug`; qa/staging = `info`; production = `error`. Set them per environment via `LOG_LEVEL`, never in code. Library fallbacks stay safe (go-log's unset default is `info`). Chart defaults are production-safe (`error`), and a dev values overlay sets `debug`. Local dev logs are human-readable, never JSON: local run targets (Taskfile, `.env.example`) set `LOG_LEVEL=trace LOG_FORMAT=console`. Every cluster logs JSON.

## health

- Every app's readiness (gRPC health and /readyz) fails while a required dependency (Postgres, RabbitMQ, Valkey, OPA, Kratos and the like) is down, using cached short-timeout pings.
- Liveness checks the process only.
- Optional dependencies show as degraded.
- The health body lists each dependency's state and version.

## readme

- **README style (default; an org may override it in its org plugin):** the lite emoji treatment; the org plugin names the canonical example README.
  - the H1 is `# <name> <emoji>`, then a one-line `> <emoji> description` blockquote;
  - the prose may carry an occasional emoji to mark a key point;
  - every H2 is `## <emoji> <Title>`, and highlights and feature bullets start with an emoji plus a bold lead-in;
  - at most one emoji per line, none in code blocks, tables or H3 and below;
  - never strip emoji from a README that already follows this style. A badge row and a Status line are optional (keep them if present);
  - An org that forbids emoji in READMEs declares it, and any exception such as its members-only profile, in its org plugin; that rule wins.
- **CHANGELOG.md** is generated by the changelog action from the release-drafter categories; never hand-edit it. Go packages have no `CHANGELOG.md`: their GitHub Release notes are the changelog.

## packages

- The catalog of the owner's published packages is not loaded every turn. Read it on demand from `~/.claude/warren/catalog.md`; until the cutover, fall back to `~/.claude/CLAUDE.github-projects.md`. It lists each package with its import path and current version.
- Before writing code for a job one of them covers, use that package at the listed version, and check its README for the API first.
- If none covers it, report the gap; don't build a one-off.
- Inside the repo, a helper used in two or more places is one shared helper, never a copy (see scaffold:reuse).

## porting

A port takes code from another system and rewrites it in the house style. It is never a 1:1 copy: read the original for its behaviour, then rebuild each piece as it moves.

- **Decide the repo shape first.** Before rebuilding, decide whether the ported system lands as one repo (a monorepo) or as multi-repo microservices (one repo per service). Base the call on the system's size, its service boundaries and how it releases. Record the decision and its reason in the plan, and ask the owner when it isn't clear-cut. An org plugin says which shape its product already chose.
- **Rebuild in the house style, don't copy:**
  - this repo's layout and naming;
  - the language skill's conventions (coding:lang-*);
  - the published packages in place of the original's helpers and shared library (coding:packages); report a gap instead of writing a one-off;
  - test-first, with the original's behaviour as the spec (coding:test-first);
  - logging (coding:logging) and health checks (coding:health);
  - errors validated only at boundaries (coding:discipline);
  - no attribution to the source project (scaffold:reuse).
- **Org values become settings:** anything the original hard-coded for one organisation becomes an adopter setting, empty by default.
- **Each service owns its API contract.** A caller uses that contract and never imports another service's module.
- **Never invent a Kubernetes API group or domain.** Ask the owner.

## ui

Apply the exact pixel nudge requested, with a named px constant as the knob, and state any consequence in one line. If nudges don't converge, fix the anchor.

## Code editing (friction rules)

- Prefer the Edit tool over sed or scripted string replacement for source files. After any bulk or scripted edit, re-read the changed region and run typecheck before committing.
- After a reformat (oxfmt), re-read the file before editing, because line positions change.
- Do not add dependencies implicitly; use TypeScript types, not `propTypes`.
- Process management: never use broad `pkill` or `pgrep` patterns. Kill only specific PIDs or ports that you started.

## Engineering discipline (extras)

- Map every reference before removing a feature: trace its wiring across the tree first, preserve adjacent behaviour that only looks related, and defer and flag an entangled piece instead of guessing.
- Green CI is necessary, not sufficient: run the real check for what changed (lint, a full build or render, `actionlint` for workflows) before calling it done.
- One concern per branch and PR, even tiny ones. When PRs interact, state an explicit merge ORDER: anything a tag triggers needs its inputs on `main` first; a new gate needs the violations it catches fixed first; a workflow that builds from committed content needs that content merged first.
- Semver framing: `breaking` only means breaking against a released version; removing something never shipped is not breaking.
- **No backwards compatibility before the first release:** before a solution's first release, nothing needs to be backwards compatible: no redirects, aliases, deprecated fields, shims, compatibility code or migrations for old shapes. Change it cleanly and remove the old way in the same change. Once a release exists, compatibility is owed (the SDLC says we support what we released, semantic versioning says until a breaking-change version), so deprecate first and remove only in a breaking-change release.
- Cross-repo reconciliation goes through a neutral drop-zone outside both repos, never a repo inside a repo, and no accidental gitlinks or submodules.
