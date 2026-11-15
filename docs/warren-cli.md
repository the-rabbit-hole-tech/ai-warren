# warren CLI

`warren` sets up a machine for the ai-warren plugins. It installs the tools, adds the ai-warren
marketplace, installs the plugins, and sets up the git identity guard, then keeps checking that
all of it stays in place. It needs no claude session to run, so it works on a fresh machine.

## Before you start

- macOS with [Homebrew](https://brew.sh), or a Debian or Ubuntu Linux (apt-get; sudo when you
  are not root).
- `gh` (signed in) or a browser, to download the binary from the GitHub release; or Go, to build it.

## Install

1. Download the archive for your machine from the latest release:
   `gh release download -R the-rabbit-hole-tech/ai-warren -p 'warren_*_linux_arm64.tar.gz'`
   (use `darwin` or `linux` and `amd64` or `arm64`).
2. Unpack it and put `warren` on your PATH: `tar xzf warren_*.tar.gz warren && sudo mv warren /usr/local/bin/`.
   Check the archive against `warren_*_checksums.txt` from the same release. Or build it:
   `go install github.com/the-rabbit-hole-tech/ai-warren/cmd/warren@latest`.
3. Run `warren init`.

## Commands

| Command | What it does |
| --- | --- |
| `warren init` | Asks one question at a time (role, org plugins, the GitHub login, name and email for the guard, then confirm) and runs every step that is not in place yet. |
| `warren init --config <file.yaml>` | Runs the same steps with the answers from a file and asks nothing. For agent machines and containers. |
| `warren init --only machine\|github\|secrets` | Runs one group of steps. `machine` is everything but `gh-auth`; `github` is `gh-auth`; `secrets` has no steps yet. |
| `warren init --dry-run` | Checks every step and says what would change, changing nothing. |
| `warren init --allow-identity-change` | Lets `guard-identity` replace a different identity that is already set. Without it, a different identity is left alone. |
| `warren step <name> --answers -` | Runs one step with the answers as JSON on stdin and prints one JSON result. `--check` only checks. The skills call this. |
| `warren doctor [--json]` | Checks every step against the answers `init` last ran with (kept in `~/.config/warren/answers.json`) and changes nothing. |
| `warren version` | Prints the version and commit. |

`--marketplace-source <source>` (or `WARREN_MARKETPLACE_SOURCE`) adds the ai-warren marketplace
from somewhere other than `the-rabbit-hole-tech/ai-warren`: a git URL or a local folder.

## Steps

Every step checks first and changes only what is missing, so `init` is safe to run again.

| Step | Checks | Sets up |
| --- | --- | --- |
| `tools` | tmux, gh and claude are installed (claude on PATH or in `~/.local/bin`) | `brew install` on macOS, `apt-get install -y` on Linux, claude from its official installer |
| `marketplace` | `claude plugin marketplace list --json` lists ai-warren | `claude plugin marketplace add <source>` |
| `plugins` | `claude plugin list --json` has each plugin at user scope | `claude plugin install <id> --scope user` |
| `guard-identity` | the global git config has `guard.expectedLogin`, `guard.expectedName`, `hooks.expectedAuthorEmail`, `user.name` and `user.email` from the answers | sets them from the answers' `github` block only; a different identity already set is drift and is left alone |
| `guard-sync` | `~/.config/git/hooks` links to `~/.config/warren/git-hooks` and the global `core.hooksPath` names the link | runs the plugin's `bin/warren-guard-sync`; on a fresh machine also makes the link and sets `core.hooksPath`. Either one pointing elsewhere is drift and is left alone. A plugin older than the installed copy keeps the copy and reports it |
| `gh-auth` | gh is signed in to github.com | `gh auth login --with-token`, with the token read from the variable `github.token_env` names and passed on stdin; skipped when that variable is empty |
| `path` | `~/go/bin` is on PATH (for Go-installed tools) | adds one marked line to `~/.zshrc` (macOS) or `~/.bashrc` (Linux) |
| `lessons-log` | the lessons log exists at `~/.claude/warren/lessons-log.md`, or at `$WARREN_LESSONS_LOG` when set | creates it with a one-line header; an existing log is never changed |

### On-demand steps

These run only when named (`warren step <name>`), never as part of `init` or `doctor`. The /warren
menu calls them.

| Step | Checks | Sets up |
| --- | --- | --- |
| `repo-settings` | the repo's settings declare the ai-warren marketplace (GitHub source) and enable `warren@ai-warren` plus `repo.plugins`, and `claude plugin list --json` has each installed for that repo | writes the settings, keeping every key already there in its order, then `claude plugin install <id> --scope project` in the repo. A public repo uses `.claude/settings.local.json`, `--scope local`, and a line in the repo's own `.git/info/exclude` when nothing ignores the file. A marketplace already declared with another source is drift and is left alone. `--marketplace-source` changes the source it declares |
| `update` | every installed ai-warren plugin matches the version in the local marketplace copy | `claude plugin marketplace update ai-warren`, then `claude plugin update <id> --scope <scope>` for each plugin behind it, in its repo for project and local scopes |

`repo-settings` is optional: a repo with no declaration is normal, and `check` reports `WARREN-REPO-NOT-SET-UP` only as information. It takes a `repo` block:

```json
{"version": 1, "repo": {"dir": "/path/to/repo", "visibility": "private", "plugins": ["github@ai-warren", "coding@ai-warren"]}}
```

`visibility` is `public`, `private` or `internal`. `marketplaces` (name to `owner/repo`) adds an
org's marketplace.

## The answers file

```yaml
version: 1
role: agent-machine        # ops | contributor | agent-machine
tools: [tmux, gh, claude]
github:
  login: testperson
  name: testperson
  email: 1+testperson@users.noreply.github.com
  token_env: GH_TOKEN      # read from the environment at run time, never from the file
  signing: none            # none | ssh
  guard: per-host          # always per host
secrets:
  enabled: false
  url: ""
  secret_paths: []
marketplaces: [ai-warren]
plugins: [warren@ai-warren]
org_plugins: []
```

The file names where secrets come from and never holds one. `warren` rejects it with
`WARREN-CONFIG-SECRET` when a `token`, `password`, `key` or `secret` field has a value, or when any
value looks like a credential (`ghp_`, `github_pat_`, `sk-ant-`, `glpat-`, an AWS key id, a
private key header). The error names the field, never the value.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | every step done, or doctor found everything in place |
| 1 | a step or an external command failed |
| 2 | bad command line, or the answers are invalid or hold a secret |
| 3 | doctor found a step missing or drifted |
| 4 | the guard identity or hooks link is set differently; nothing was changed |

Errors start with a stable name such as `WARREN-GUARD-NO-IDENTITY`; `warren step` puts it in the
JSON result's `code` field. The names live in `internal/codes`.

## Logging

Logs go to stderr, so `--json` output on stdout stays clean. `LOG_LEVEL` (`trace` to `error`) and
`LOG_FORMAT` (`console` or `json`) set them; `-v` turns on trace when `LOG_LEVEL` is unset. Every
external command is logged with its target, duration and outcome. Tokens are never logged.

## Develop

```bash
task test            # go test ./...
task lint            # gofmt, golangci-lint, yamllint
task build:warren    # bin/warren
task run -- doctor   # runs against THIS machine, with trace logging
```

### The clean-container run

`task test:container` (or `bash test/container/run.sh`) builds a `debian:stable-slim` image with
only curl, git, CA certificates and python3 (the guard's pre-push scrub gate runs on it), the
linux `warren` binary for Docker's architecture, and a copy of the plugin tree as a local
`directory` marketplace. It runs `warren init --config /test/agent-machine.yaml` with `GH_TOKEN`
unset, runs it a second time to show nothing changes, checks `warren doctor --json`, then commits
and pushes to a local bare repo as testperson and checks that a commit as another author is
blocked. The container runs with `--rm` and the image is removed afterwards.

- `WARREN_PLUGIN_TREE`: the folder holding `.claude-plugin/marketplace.json` (default: this repo).
- `WARREN_TEST_WORKDIR`: where to stage the build context (default: a temp folder).

It needs Docker and network access: apt, the claude installer and Docker Hub.

Every external command goes through `internal/sysexec.Exec`; tests use the fake in
`internal/sysexec/sysexectest`, so no test touches the machine it runs on.
