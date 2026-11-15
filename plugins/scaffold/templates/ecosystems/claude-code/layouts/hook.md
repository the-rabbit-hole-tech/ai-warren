A Claude hook: one bash script that Claude runs on a hook event, handing it a JSON
payload on stdin. It may block or modify the action through its documented output.

### Tree

```text
.
├── <script>.sh           the script Claude runs
├── install.sh            copies <script>.sh into ~/.claude and prints the settings snippet
├── tests/
│   ├── run.sh            plain-bash runner: every *.test.sh, exits non-zero on any failure
│   ├── <case>.test.sh    one file per behaviour
│   └── fixtures/         sample stdin payloads (*.json)
├── .github/workflows/    one checks workflow (shellcheck and tests/run.sh), release drafter
├── Taskfile.yml          lint and test tasks, the same commands CI runs
├── CLAUDE.md
├── README.md             what it shows or does, install, the settings snippet
└── LICENSE
```

### What goes where

- `<script>.sh`: the whole add-on. `#!/usr/bin/env bash` and `set -uo pipefail`, never `-e`: a
  failed command must not end the script early. It reads the payload from stdin once, parses it
  with `jq`, prints to stdout, and ends with `exit 0`.
- It never breaks the session: when input is missing or malformed, or a command fails, it prints
  what it can and exits 0. It may block or modify the action only through the hook's documented
  output (a JSON decision on stdout, or the exit code the event defines for blocking).
- No network access: no `curl`, `wget` or sockets. Everything comes from the payload and local
  files.
- `jq` is the only dependency beyond bash and the base tools. No Python, Node or extra binaries.
- It runs on macOS and Linux alike. Branch on the platform where tools differ, as `date` does
  between BSD (`date -r`, `date -j -f`) and GNU (`date -d`); bash 3.2 must work.
- `install.sh`: copies the script to `~/.claude/hooks/<script>.sh` (or under `$CLAUDE_CONFIG_DIR`
  when set), makes it executable, and prints the `"hooks"` event entry for `settings.json`. It
  never edits `settings.json`: the user pastes the snippet.
- State the script keeps between runs lives under `~/.claude/`, in a file named after the script.
- `.github/workflows/`: the checks workflow and release drafter. No Release Manager, manifest or
  `CHANGELOG.md`: the GitHub Release notes are the changelog. No licence-header job either:
  golic needs Go, and nothing else in a bash repo does.
- README and other Markdown docs may use the CLI's product name, which
  `.github/docs-allowed-forbidden-text.txt` allows in Markdown only. Scripts, comments, commit
  messages and PR text still may not.

### Naming

- The repo is `claude-code-<kind>-<name>`, so `claude-code-hook-<name>` for a hook. The script is
  `hook-<name>.sh`, so several hooks can share `~/.claude/hooks/`. A repo named off the pattern
  keeps its whole name: `plain` ships `hook-plain.sh`.
- Functions and local variables are `snake_case`; environment variables and constants are
  `UPPER_SNAKE_CASE`.
- Test files are `tests/<case>.test.sh`; each payload is `tests/fixtures/<case>.json`.

### Tests, fixtures and generated code

- `tests/run.sh` runs every `tests/*.test.sh` in its own bash process with a temporary `HOME`
  and no `CLAUDE_CONFIG_DIR`, so tests never touch the real `~/.claude`. It passes with no tests
  and fails when any test fails.
- A test pipes a fixture into the script and checks stdout, the exit code and any files written
  under the temporary `HOME`. Cover missing and malformed input: the script still exits 0.
- Fixtures are real payload shapes with made-up values: no session ids, paths or names from a
  real machine.
- CI runs `shellcheck` over every script and then `bash tests/run.sh`. Nothing is generated.
