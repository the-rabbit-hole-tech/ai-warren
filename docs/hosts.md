# Host files

A host file holds the values of one machine: its name and OS, paths, sessions, review windows and
tools. The shared rules and the how-to text live in the warren skills; the host file carries only what
differs per machine. Each person's host files live with them, never in this repo.

## The template

`hosts/_template/CLAUDE.host.md` is the template (Go `text/template`). The `warren` binary embeds a
copy at `internal/steps/templates/CLAUDE.host.md.tmpl`; a test keeps the two identical. Placeholders
are the fields of the `host` answers.

## The `host` step

```
warren step host --check --answers -   # missing, ok, drift or skipped
warren step host --answers -           # write the file when it is missing
```

The answers go in under `host` as JSON (or YAML for `warren init --config`):

| Field | Meaning |
| --- | --- |
| `path` | Where the file is written. Default `~/.claude/CLAUDE.host.md`. |
| `name`, `os`, `shell`, `shell_notes`, `timezone` | The machine. |
| `code_root`, `worktrees_dir`, `credentials_dir` | Folders. `credentials_dir` is a path, never a value. |
| `git_host`, `git_account`, `git_name`, `git_email` | The one git identity. `git_host` defaults to `github.com`. |
| `clis`, `hooks` | The CLIs (say which are signed in) and the session hooks. |
| `ops_session`, `coding_session`, `windows` | Sessions and project windows. |
| `review_windows`, `working_hours` | When the owner reviews and works. |
| `handoff_site`, `handoff_port`, `handoff_test_port` | Optional hand-off site. |
| `setup_dir`, `owner_queue`, `bug_logs`, `holding`, `lane_scratch`, `lessons_log` | The setup layout. `lessons_log` is `~/.claude/warren/lessons-log.md` unless `WARREN_LESSONS_LOG` names another file (see operator:self-learning). |
| `machine_notes`, `org_files`, `away`, `weekends`, `setup_notes` | The machine's own facts, added to their line. |
| `notes`, `lessons` | Further host facts, and the lessons that only make sense on this machine. |

Optional environment values, set in the user `settings.json` `env` block rather than as host answers:
`WARREN_WORK_HISTORY_REPO` names the repo (`owner/repo`) that records the owner's work history. When it
is set and a milestone finishes in a project the host records, the operator queues one low-priority
work-history lane (see operator:waves); the org plugin's work-history skill says how it runs. Unset, no
lane is queued.

`name`, `code_root`, `git_account` and `git_email` are required once any host value is given; with no
host answers the step is `skipped`. Secret-looking values are rejected like everywhere else in the
answers.

Status: `missing` when the file does not exist (Apply writes it), `ok` when it matches the render,
`drift` when it differs. Apply never overwrites a file that differs: it reports the drift and leaves
the file alone. The step writes only the one file at `path`, and never reads or copies another host's
file.

The `/warren host` skill (`plugins/warren/skills/warren-host`) asks the questions and runs the step.
`warren init --only host` runs it from saved answers.
