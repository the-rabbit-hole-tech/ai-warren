<!-- warren-host: written by `warren step host`. Host values only; the how-to text lives in the warren skills. -->
# Host rules: {{.Name}}

## This machine
- **Host:** {{.Name}} (`hostname -s`), {{.OS}}.{{if .MachineNotes}} {{.MachineNotes}}{{end}}
- **Shell:** {{.Shell}}.{{if .ShellNotes}} {{.ShellNotes}}{{end}}
- **Timezone:** {{.Timezone}}
- **Code root:** `{{.CodeRoot}}`. Repos in `<code root>/<GitHub owner>/<repo>`, forks in `_forks/<repo>`, local-only repos in `_archive/<owner>/<repo>`, `_`-prefixed folders are never repos.{{if .WorktreesDir}} Worktrees: `{{.WorktreesDir}}`.{{end}}{{if .OrgFiles}} Org files: `{{.OrgFiles}}`.{{end}}
- **Credentials:** `{{.CredentialsDir}}`. Reference by path or env var, never copy contents.

## Identity and tools
- **Git:** {{.GitHost}} only. Only `{{.GitAccount}}` commits or pushes, as `{{.GitName}} <{{.GitEmail}}>`. `hooks.expectedAuthorEmail` is set globally to that email; never unset it.
- **CLIs:** {{join .CLIs ", "}}.{{if .Hooks}}
- **Session hooks:** {{join .Hooks ", "}}, linked into `~/.claude/`.{{end}}

## Sessions and windows
- **Operator session:** {{.OpsSession}}.
- **Coding session:** {{.CodingSession}}. Windows: {{join .Windows ", "}}.
- **Review windows:** {{join .ReviewWindows ", "}}.
- **Working hours:** {{.WorkingHours}}.{{if .Away}} {{.Away}}{{end}}
{{- if .Weekends}}
- **Weekends:** {{.Weekends}}
{{- end}}
{{- if .HandoffSite}}
- **Hand-off site:** `{{.HandoffSite}}` on http://127.0.0.1:{{.HandoffPort}}/{{if .HandoffTestPort}}, test copy on http://127.0.0.1:{{.HandoffTestPort}}/{{end}}.
{{- end}}

## Layout and paths
- **Setup root:** `{{.SetupDir}}`.{{if .SetupNotes}} {{.SetupNotes}}{{end}}
- **Owner queue:** `{{.OwnerQueue}}`
- **Bug logs:** `{{.BugLogs}}`
- **Holding folder:** `{{.Holding}}`
- **Lane scratch:** `{{.LaneScratch}}`
- **Lessons log:** `{{.LessonsLog}}` (first occurrences).
{{- if .Notes}}

## Notes
{{- range .Notes}}
- {{.}}
{{- end}}
{{- end}}
{{- if .Lessons}}

## Lessons (this machine)
{{- range .Lessons}}
- {{.}}
{{- end}}
{{- end}}

## Environment
```
export WARREN_OPS_SESSION={{.OpsSession}}
export WARREN_CODING_SESSION={{.CodingSession}}
export WARREN_HOLDING={{.Holding}}
export WARREN_OWNER_QUEUE={{.OwnerQueue}}
export WARREN_HANDOFF_SITE={{.HandoffSite}}
```
