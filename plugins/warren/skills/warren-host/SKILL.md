---
name: warren-host
description: Use when setting up this machine's host file (paths, sessions, review windows, tools) with /warren host.
disable-model-invocation: true
---

# Set up this machine's host file

Writes the host file from the template with `warren step host`. The step only ever writes the one
file at the chosen path and never overwrites a file that differs.

## Before you start

- Check `warren` is on PATH (`command -v warren`). If not, install it as `docs/warren-cli.md` in
  the ai-warren repo says, then continue.
- Never ask for, read or copy another machine's host file. Credentials folders are paths only.

## Steps

1. Ask the host questions with AskUserQuestion, one question at a time. Offer sensible choices where
   there are some; take free text through Other.
   1.1. Machine: name, OS, shell and shell notes, timezone.
   1.2. Folders: code root, worktrees folder, credentials folder (a path, never a value).
   1.3. Git: host, account, commit name and email (the one allowed identity).
   1.4. Tools: CLIs (which are signed in), session hooks.
   1.5. Sessions: operator session, coding session, project windows, review window times,
   working hours.
   1.6. Optional hand-off site: folder, port, test port.
   1.7. Setup layout: setup root, owner queue, bug logs, holding folder, lane scratch, lessons log.
   1.8. Optional machine facts: notes for the host line, org files, what outside working hours
   means (away), weekends, setup notes, further notes, and the lessons that only make sense here.
   1.9. Where to write the file (default `~/.claude/CLAUDE.host.md`).
2. Build the answers as JSON with the values under `host` (snake_case keys: `name`, `os`, `shell`,
   `shell_notes`, `timezone`, `code_root`, `worktrees_dir`, `credentials_dir`, `git_host`,
   `git_account`, `git_name`, `git_email`, `clis`, `hooks`, `ops_session`, `coding_session`,
   `windows`, `review_windows`, `working_hours`, `handoff_site`, `handoff_port`,
   `handoff_test_port`, `setup_dir`, `owner_queue`, `bug_logs`, `holding`, `lane_scratch`,
   `lessons_log`, `machine_notes`, `org_files`, `away`, `weekends`, `setup_notes`, `notes`,
   `lessons`, `path`) and `"version": 1`. The `host` answers table in `docs/hosts.md` lists every field.
3. Run `warren step host --check --answers -` with the JSON on stdin. Show the status and, for
   `missing` or `drift`, what would be written (the path and the template's render).
4. Ask Yes or No with AskUserQuestion. On No, stop and change nothing.
5. On Yes, run `warren step host --answers -` with the same JSON.
6. Report the JSON result (`step`, `status`, `changed`, `message`, and `error` and `code` on failure).
   On drift, say the file was left alone and offer to write the new render to another path.
7. Suggest exporting the Environment block's `WARREN_*` lines in the shell profile. Do not edit the
   profile unasked.
