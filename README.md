# ai-warren 🕳️

> 🐇 the rabbit hole's agent factory: plugins, skills and the warren CLI for anyone who builds with Claude Code.

<p align="center"><img src="assets/warren-mark.svg" alt="the warren mark: one entrance at the top, tunnels branching down to three chambers" width="128"></p>

Every agent session used to read the whole rule stack on every turn. ai-warren turns those rules
into Claude plugins: a short always-on core, and skills that load only for the step an agent is
on. 🛡️ **The hard stops stay local:** the git identity guard, the scrub and secrets gate, the
forbidden-text checks and the Marketplace release guard run as hooks on your machine.

## ✨ Highlights

- 🌱 **The warren plugin** — always on: about 17 lines of rules at the start of every session,
  and the hard stops.
- 🧩 **Skills per step** — GitHub flow, coding, design, scaffolding, operator work and secrets,
  each loaded only when the step needs it.
- 🏛️ **Your own rules on top** — write an org plugin and the base layers yours over its defaults.
- 🔐 **One identity per person per machine** — the git guard reads it from your global git
  config and blocks every commit and push until it's set.
- 🧹 **Scrub before push** — secrets, attribution trailers and AI-tell phrasing never leave the
  machine, and a private term list of your own (kept outside any repo) is checked too.
- 🧰 **The warren CLI** — `warren init` sets a machine up one question at a time, or unattended
  from a YAML file.

## 🌱 Where the name comes from

A warren is the network of burrows where a whole colony of rabbits lives and works together:
many tunnels, many chambers, one home. That's what this is. One system where many agents each
dig into their own piece of work and come back to the same place.

## ⚠️ What it changes on your machine

Read this before you install. ai-warren is opinionated, and the guard is meant to stop you.

- `warren init` takes over the **global** `core.hooksPath` (through a link at
  `~/.config/git/hooks`) and requires `guard.expectedLogin`, `guard.expectedName` and
  `hooks.expectedAuthorEmail` in your global git config. Until they are set, **every commit and
  push on the machine is blocked**.
- Defaults you may not expect: no attribution trailers in commits or PRs, no emoji in source or
  commit messages (README and other Markdown files are exempt), Conventional Commit titles,
  drafts first, GitHub-hosted CI runners only. The emoji rule, and any other default, can be
  overridden by an org plugin or by a single project's own rules.
- The always-on text costs about 17 lines of context per session. Skills cost their one-line
  description each until loaded.

## 🚀 Getting started

### Before you start

- The claude CLI installed, and `git`.
- `gh` signed in if you want the repo flows (`gh auth login`).

### 1. Install the plugin

```bash
claude plugin marketplace add the-rabbit-hole-tech/ai-warren
claude plugin install warren@ai-warren
claude plugin list
```

The other plugins are optional and installed the same way: `github`, `coding`, `design`,
`handoff`, `operator`, `scaffold` and `secrets` (`claude plugin install github@ai-warren`).

### 2. Set up the machine with the CLI

Download the archive for your machine from the
[latest release](https://github.com/the-rabbit-hole-tech/ai-warren/releases/latest), check it
against the `warren_*_checksums.txt` file there, and unpack it:

```bash
gh release download -R the-rabbit-hole-tech/ai-warren -p "warren_*_$(uname -s | tr '[:upper:]' '[:lower:]')_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').tar.gz" -p "warren_*_checksums.txt"
shasum -a 256 --ignore-missing -c warren_*_checksums.txt
tar -xzf warren_*.tar.gz warren
```

Or build it with Go:

```bash
go install github.com/the-rabbit-hole-tech/ai-warren/cmd/warren@latest
```

Then run it and answer the questions (this machine, your GitHub, your password manager if you
use one). `warren doctor` checks the result.

```bash
./warren init
./warren doctor
```

On a machine with no prompts (an agent machine or a container), pass a config instead:
`./warren init --config agent-machine.yaml`. See [docs/warren-cli.md](docs/warren-cli.md).

### 3. First run

Start a new Claude session in a repo. The warren text is in its context from the first turn, and
skills load as you reach each step (an issue, a branch, a PR, a release). Type `/warren:menu` to
see what you can set up: a new org, a project or repo, a release, a host file.

If the repo's owner has no org plugin, the session says so and the base rules still apply.

## 🏛️ Write your own org plugin

An org plugin holds the rules that are yours on top of the base. Layers go warren, then language,
then your org, then the repo; a lower layer only tightens, and an org skill that changes a base
rule says so in an `Overrides` line.

1. Install the `scaffold` plugin, then run `/scaffold:warren-org` in a session. It builds the
   plugin from the shipped template with `warren-new-org-plugin`. Inside a Claude session the
   plugin's `bin/` folder is on the PATH; from a plain terminal, run it from a clone of this repo
   (outside any other repo's folder):

   ```bash
   plugins/scaffold/bin/warren-new-org-plugin my-org --out ~/Code/my-org-warren --author "The my-org Authors"
   ```

   The marketplace is named for your GitHub owner in lower case and the plugin is
   `warren-org-<owner>`. Keep that naming: it is how the base finds your plugin.
2. Edit its `skills/rules/SKILL.md` (or add a skill per step) and its `scaffold/scaffold.conf`
   (copyright holder, licence, operator handle for new repos).
3. Push it to a repo you own, then install it:

   ```bash
   claude plugin marketplace add my-org/my-org-warren
   claude plugin install warren-org-my-org@my-org --scope user
   ```

4. In one of your repos, `plugins/warren/bin/warren-repo-ready` (from a clone of this repo, or
   `warren-repo-ready` inside a session) prints `ready` when the plugin is found.

### Your private term list

The scrub checks can also look for names you never want in a repo (a client, a host, a person).
Keep that list **outside any repo**: `*.txt` files in `~/.config/warren/terms/` (or the folder in
`WARREN_TERMS_DIR`). See [docs/examples/warren-terms.example.txt](docs/examples/warren-terms.example.txt).
Hits print the file and line, never the term.

## 🔕 Opt out and uninstall

- Silence the session note about a missing org plugin: `WARREN_ENFORCE=off`.
- Skip folders: `WARREN_EXEMPT=/path/one:/path/two`.
- Remove a plugin: `claude plugin uninstall warren@ai-warren`.
- Give the machine its own hooks back: `git config --global --unset core.hooksPath`, then remove
  the `~/.config/git/hooks` link. The identity guard is a git hook; without it nothing is blocked.

## 🛠 Develop

```bash
bash tests/run.sh       # plugin tests (the guard tests skip outside a sandbox)
bash tests/sandbox.sh   # every test, in a throwaway Docker container
task test               # Go tests
task lint               # gofmt, golangci-lint, yamllint
```

See [.github/CONTRIBUTING.md](.github/CONTRIBUTING.md). Releases are built by
`.github/workflows/release.yaml` when a `v*` tag is pushed.

## 🙏 Acknowledgements

Created by Bugs5382, the original author, and shaped by everyone listed in [AUTHORS](AUTHORS).

## ⚖️ License

Apache-2.0. Copyright 2026 The ai-warren Authors. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
