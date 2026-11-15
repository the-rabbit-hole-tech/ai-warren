# scaffold

Repo governance and scaffolding for ai-warren: the shared governance, the ecosystem templates and the
scripts that create a repo or bring one under governance. Everything here is generic. The values that
belong to one owner come from that owner's org or personal plugin (see [Owner settings](#owner-settings)).

## Scripts (`bin/`, on the Bash tool's PATH)

| Script | What it does |
| --- | --- |
| `warren-new-repo <name> <eco> [--org <owner>] [--private] [--variant <v>] [-d <desc>] [--existing\|--no-remote\|--dry-run] [--out <dir>] [--scaffold-dir <dir>]` | Composes the ecosystem template, the shared governance and the owner's files, fills the tokens, commits, creates the GitHub repo, pushes, and applies the ruleset and topics. `--dry-run` writes the filled tree only (no git, no GitHub calls) and prints what a real run would do. |
| `warren-apply-governance [--sync] [--eco <eco>[/<variant>]] [-d <desc>] [--force] <repo>` | Lays the shared governance into an existing repo without committing. `--sync` is the full shared set; `--eco` adds the ecosystem CI files the repo lacks. A repo the owner lists as protected is refused unless `--force`. |
| `warren-apply-ruleset [--print] <owner/repo> [ruleset.json] [--require <check>]...` | Creates or updates the branch ruleset and sets the merge policy (squash only, auto-merge, delete branch). `--org <org> [ruleset.json]` applies an org-level ruleset. |
| `warren-apply-topics [--print] <owner/repo> <eco> [variant]` | Adds the ecosystem's base topics and the owner's own topics. |

The scripts find their templates from their own folder (`${CLAUDE_PLUGIN_ROOT}` isn't set in the Bash
tool). `lib/scaffold.sh` holds the shared code.

Ecosystems (`templates/ecosystems/`): action, claude-code, fastify, go, npm, python, storybook, swift,
vite, and rust (layouts and topics only). Each has `layouts/variants` (default first), `topics`, and
optionally `topics.<variant>`, `image.variants`, `workflows.skip`, `sync.overlay/`, `variant.overlay/`
and `private.overlay/`.

## Owner settings

An owner (a GitHub org or user) keeps its own values in a `scaffold/` folder in its org or personal
plugin:

```text
<plugin>/scaffold/
├── scaffold.conf      key=value settings (below)
├── CODEOWNERS         replaces the CODEOWNERS baseline; on --sync its missing lines are added
├── ruleset.json       the owner's branch ruleset, used as it is
├── governance.skip    shared files the owner doesn't take (its .github repo provides them), one
│                      repo-relative path a line
├── labels.yml         replaces the canonical label set
├── topics             topics every new repo of the owner gets, one a line
├── protected          repos the shared governance never touches, one name a line (# comments);
│                      warren-apply-governance refuses them (exit 3) unless --force
├── repo-skip          `<repo> <path>` lines: a shared file one repo keeps out because it carries
│                      its own (for example its own licence-header workflow)
└── overlay/           files a new repo starts with (LICENSE, NOTICE, a required CI caller); also
                       added by warren-apply-governance --eco where the repo lacks them
```

Every file is optional. The scripts pick the folder by owner, in this order:

1. `--scaffold-dir <dir>` on the command line;
2. `WARREN_SCAFFOLD_DIRS`, a colon-separated list of `scaffold/` folders (set it in the host file's
   Environment block, like the other `WARREN_*` values);
3. the `scaffold/` folders of the plugins in the installed marketplaces
   (`${CLAUDE_CONFIG_DIR:-~/.claude}/plugins/marketplaces/*/plugins/*/scaffold`).
   `WARREN_SCAFFOLD_SEARCH=0` turns this step off.

The first folder whose `scaffold.conf` lists the owner in `owners=` wins (case is ignored). An owner
with no folder gets the generic defaults, and the scripts say so on their first line.

### `scaffold.conf` keys

| Key | Default | Used for |
| --- | --- | --- |
| `owners` | (required) | the GitHub owners this folder serves, space or comma separated |
| `author` | the owner, with a note | the copyright holder in LICENSE, NOTICE, README, manifests and golic headers. A person or "The <Product> Authors", never a handle by accident |
| `license` | `Apache-2.0` | the SPDX id in README, manifests and Taskfile text. The base ships the text for `Apache-2.0` and `MIT`; any other licence needs `overlay/LICENSE` |
| `golic-license` | `apache2` (`mit` for MIT) | the golic template key |
| `operator` | the owner | the handle `CLAUDE.md` names as the author of record and assignee |
| `dco` | `false` | `true` signs the first commit off |
| `notes-dir` | `plan/` | the git-ignored local notes folder (`.local/` for public repos of a private setup) |
| `release-drafter-extends` | empty | a shared release-drafter config (`<owner>/.github@main`) the release workflows extend; the repo then gets no local `release-drafter.yml` |
| `release-app-id` | empty | the release GitHub App's id, added as a bypass actor to the default ruleset so the Release Manager can push its `[skip ci]` commit |
| `funding` | empty | the GitHub Sponsors account written to `.github/FUNDING.yml`; no file without it |
| `readme-emoji` | `true` | `false` strips the README emoji |

Lines starting with `#` are comments.

## Tokens

The templates carry `__OWNER__`, `__REPO_NAME__`, `__DESCRIPTION__`, `__AUTHOR__`, `__YEAR__`,
`__LICENSE__`, `__GOLIC_LICENSE__`, `__OPERATOR__`, `__NOTES_DIR__`, `__RELEASE_DRAFTER_EXTENDS__`,
`__PKG__` (Go package), `__PYPKG__` (Python module) and `__SCRIPT_NAME__` (claude-code add-on). They
are filled literally; path names with a token are renamed.

## Tests

`tests/scaffold/*.test.sh` (`bash tests/run.sh scaffold`). `new-repo.test.sh` makes commits and runs
only in the sandbox (`bash tests/sandbox.sh scaffold`). The fixtures under `tests/scaffold/fixtures/`
are two made-up owners.
