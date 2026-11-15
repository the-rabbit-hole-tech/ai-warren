---
name: lang-go
description: Use when writing or reviewing Go code (a repo with go.mod): layout, cobra for CLIs, error handling, go-apperr and go-log.
---

# Go rules

The global rules come first; this adds Go detail and never overrides them.

- **Layout:** follow the repo's layout block (defined in your shared rules repo) once the repo has one. The shared rules repo's Go layouts (app, cli, lib) are the reference.
- **CLIs:** Go CLIs always use `github.com/spf13/cobra` for commands and flags. The org's reference CLI repo, named by the org plugin, shows how commands are built and wired.
- **Errors:** always handle returned errors (that is the contract); don't add checks for states the caller already guarantees.
- **Coded errors and logging:** coded errors use `go-apperr` and logging uses `go-log` (see coding:packages for versions).
