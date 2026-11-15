# AGENTS.md - ai-warren

Guide for AI agents working in this repository. Pair with `CLAUDE.md` (the working agreement and
hook-enforced rules). Keep this file current when the build, layout, or public API changes.

## What this is

the rabbit hole's agent factory: plugins, skills and the warren CLI

It ships two things that change together: the ai-warren plugin marketplace
(`.claude-plugin/marketplace.json`, plugins and skills) and the `warren` Go CLI that installs them
on a machine (`cmd/warren`). Phase 1 ships one plugin, `warren`, which is always on: a short rule
text injected at session start and the hard stops (git identity guard, scrub gate, command
guards). The CLI's steps are the only place step logic lives: the interactive `warren init`,
`warren init --config`, `warren doctor` and the skills (through `warren step <name> --answers -`)
all run the same `internal/steps`. `docs/warren-cli.md` is the user guide.

The hard stops are the part where a shipped mistake hurts: never weaken a guard to get a test or
a push through. A guard that can't verify something must block.

## Using ai-warren

- Marketplace name `ai-warren`; plugins live under `plugins/<name>` with
  `.claude-plugin/plugin.json`. Bump the plugin `version` on every change that ships.
- `plugins/warren/warren.md` stays at 22 non-blank lines and 2,500 characters or fewer
  (`tests/warren/warren-text.test.sh`).
- The guard reads its identity from the global git config only, so a repo can't change who may
  commit. `warren-guard-sync` never changes `core.hooksPath` or the hooks link.
- The skills call `warren step <name> --answers -` with the answers as JSON on stdin and read one
  JSON object back (`step`, `status`, `changed`, `message`, and `error` and `code` on failure). The
  exit codes and error names in `docs/warren-cli.md` are part of that contract. A step never
  changes the guard identity or an existing `core.hooksPath` as a side effect: those report drift.

## Skills

- Frontmatter: `name` (the folder name) and `description` (starts with "Use when", 300 characters
  or fewer). Menu skills (`menu`, `warren-*`) set `disable-model-invocation: true`.
- Write each rule short and in the imperative, keeping its meaning exactly: no new rules, nothing
  weakened, every dated lesson's substance kept in a `## Lessons` section of the skill for its step.
- `tests/skills/` checks that the model-invocable descriptions stay within 12,000 characters together.

## Layout

- `.claude-plugin/marketplace.json` - the marketplace
- `plugins/design/` - the design and review rules as skills (`design:brainstorm`, `plans`, `section-review`, `design-session`, `new-ui`)
- `plugins/scaffold/` - repo governance and scaffolding skills (`governance`, `new-repo`, `adopt-repo`,
  `licence`, `reuse`, `helper-repo`) and the `warren-org` and `warren-project` menu skills
- `plugins/warren/` - the always-on plugin: `warren.md`, `hooks/` (session and Bash hooks),
  `git-hooks/` (the guard and the scrub gate), `bin/warren-guard-sync`,
  `bin/warren-repo-ready` and `hooks/repo-ready.sh` (the advisory "are the owner's rules there" check: the repo owner's org plugin is installed and enabled; a repo's own settings are only overrides), the
  operator scripts in `bin/` (tests in `tests/warren-bin/`) and the `scripts` skill
- `plugins/<name>/skills/<skill>/SKILL.md` - the skills
- `plugins/github/` - the GitHub flow as skills (issues, branches, PRs, CI, approvals, cleanup, repo
  metadata, profiles, releases, the Cut trigger) and the `warren-release` menu
- `plugins/coding/` - the coding and language rules as skills (`test-first`, `discipline`, `docs`,
  `logging`, `health`, `readme`, `ui`, `packages`, `porting`, `lang-*`)
- `plugins/operator/` - the operator rules as skills (`skills/`), the tmux scripts (`bin/`) and the pane-tag hook (`hooks/`); its tests are in `tests/operator/`
  `git-hooks/` (the guard and the scrub gate), `bin/warren-guard-sync`, `skills/` (the /warren menu
  and its warren flows)
- `tests/` - shell tests: `run.sh` runs every `*.test.sh`, `sandbox.sh` runs them in a
  throwaway container with the commit-making guard tests turned on
- `cmd/warren/` - `main.go`: `run(args, stdin, stdout, stderr)` and the exit-code constants.
- `internal/commands/` - the Cobra commands, one constructor per file (`init`, `step`, `doctor`,
  `version`), plus `shared.go` (the run loop) and `common_flags.go`.
- `internal/answers/` - the `Answers` struct, YAML and JSON loading, the secret check.
- `internal/steps/` - one file per step (`tools`, `marketplace`, `plugins`, `guard_identity`,
  `guard_sync`, `gh_auth`, `path`, `host`) and `Registry`/`RegistryFor`.
- `internal/sysexec/` - the `Exec` interface every external command goes through;
  `sysexectest/` is the fake the tests use.
- `internal/prompt/` - the `Prompter` interface and its charmbracelet/huh implementation.
- `internal/codes/` - the `WARREN-*` error codes on go-apperr.
- `internal/logging/` - the go-log logger (stderr).
- `test/container/` - the clean-container run: `Dockerfile`, `run.sh` and the example answers.
- `hosts/_template/` - the host-file template (`warren step host` embeds a copy); `docs/hosts.md`,
  `docs/host-rules.md` and `docs/host-draft/` - the step's guide, the host rules' places and the
  trimmed Mac draft (not applied anywhere).
- `adapters/handoff-web/` - the hand-off web site (python server, React app, installer, tests), moved in from Bugs5382/claude-handoff-web with its history. It keeps its own MIT `LICENSE` and its own `AGENTS.md`/`CLAUDE.md`; it is not part of the Go build. See `docs/adapters.md`
- `.goreleaser.yaml` - the release archives, `warren_<version>_<os>_<arch>.tar.gz`.
- `plugins/handoff/` - the hand-off site rules as skills (`handoff:site`, `review-page`, `phased-plan`, `signoff`, `for-people`) and the UserPromptSubmit inbox hook (`hooks/inbox-check.sh`, site folder from `WARREN_HANDOFF_SITE`)
- `plugins/secrets/` - the optional password manager connector: the credential skills and the
  `warren-secrets` menu step. The org or personal plugin supplies the MCP server; none ships here

## Build, test, lint

Set `GOWORK=off` when this clone sits under a folder with a `go.work` that doesn't list it.

- Build: `task build:warren` (writes `bin/warren`)
- Test: `task test` (`go test ./...`; no network, no Docker, never touches the machine: every
  external command goes through the fake Exec); `bash tests/run.sh` (plugin tests; the guard
  tests skip outside a sandbox); `bash tests/sandbox.sh` (every plugin test, in Docker)
- Clean-container run: `task test:container` (needs Docker and network; see
  `test/container/run.sh` for the plugin tree it uses as a local marketplace)
- Lint: `task lint` (gofmt, golangci-lint, yamllint), `go vet ./...`,
  `shellcheck -S warning` on `plugins/*/hooks/*.sh`, every shell script in `plugins/*/bin/` and
  `plugins/*/git-hooks/_dispatch` (see the Plugin Checks workflow),
  `claude plugin validate . --strict`
- License headers: `task license` (check), `task license:fix` (add)
- Hand-off web adapter: run its commands from `adapters/handoff-web` (see its `AGENTS.md`); the `Hand-off web` workflow runs them on changes under that folder only

## Logging

Follow the logging rules in `CLAUDE.md`. In short:

- Log generously: entry and exit of significant operations, decisions and branches, retries, state
  changes, external calls (target, duration, outcome), and every error with its context.
- Levels: `trace` for step-by-step detail, `debug` for flow, `info` for lifecycle, `warn` and
  `error` for problems. The environment filters the volume, so err on the side of too much.
- Environments: local dev `trace` with `LOG_FORMAT=console` (never JSON), dev cluster `debug`,
  qa/staging `info`, production `error`. Every cluster environment logs JSON. Set levels through
  `LOG_LEVEL` and `LOG_FORMAT`, never in code; local settings live in the run target or
  `.env.example`.
- Never log secrets, tokens, or personal data, not even at `trace`. Log an opaque or keyed ID.

## Conventions and gotchas

- See `CLAUDE.md` for the branch/commit/PR rules; they are enforced by the git hooks in
  `.claude/hooks` (run `bash .claude/hooks/install.sh` once per clone).
- Open every PR as a draft. CI skips drafts, so run the full checks locally, push once they pass,
  and mark the PR ready when the work is finished; see CLAUDE.md "CI and Actions minutes".
- Every external command goes through `sysexec.Exec`, so tests never install or change
  anything. Check the real claude CLI's JSON shapes against an isolated `CLAUDE_CONFIG_DIR` and
  `HOME`, never your own `~/.claude`.
- `warren-repo-ready` is advisory: it exits 0 with a status word and never blocks. Blocking per org
  is a later phase.
- Tokens travel on stdin only; never put one in a command's arguments, environment or a log line.
- The `tools` step finds claude on PATH or in `~/.local/bin`, where its installer puts it.
- Tests that make commits run only with `WARREN_TEST_SANDBOX=1` (CI, or `tests/sandbox.sh`),
  so they never use a test identity on a person's own machine.
- Fake secrets and AI-tell phrases in tests are assembled at run time, so the files pass the
  hooks and the scrub gate they test.
