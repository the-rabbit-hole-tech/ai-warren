A Go command-line tool that builds one binary, with its commands on Cobra (`spf13/cobra`).

### Tree

```text
.
├── cmd/<name>/
│   ├── main.go           os.Exit(run(args, stdout, stderr)); run maps errors to exit codes
│   └── main_test.go      drives run() in-process
├── internal/
│   ├── commands/         the Cobra commands, one constructor per file
│   │   ├── root.go       RootCmd(): subcommands, persistent -v/--verbose, help by default
│   │   ├── <name>.go     <Name>Cmd() *cobra.Command, with its own options struct
│   │   ├── version.go    VersionCmd()
│   │   ├── common_flags.go  flags shared by several commands
│   │   └── shared.go     helpers the commands share (validation, the run step)
│   ├── config/           config file and environment loading into a typed struct
│   └── <domain>/         the work itself, one package per job
├── testdata/             test fixtures and golden files
├── .goreleaser.yaml      release builds
├── go.mod
├── Taskfile.yaml
└── .golangci.yml
```

### What goes where

- `cmd/<name>/main.go`: `main` sets up logging and calls `os.Exit(run(os.Args[1:], os.Stdout,
  os.Stderr))`. `run` builds `commands.RootCmd()`, calls `SetArgs`, `SetOut` and `SetErr`, sets
  `SilenceErrors` so the error is reported once, by `run`, and maps typed errors (`errors.As`) to
  exit codes. The exit codes are part of the CLI contract: they are constants with a comment each,
  and the README lists them. No other logic.
- `internal/commands/root.go`: `RootCmd()` builds the root command, adds every subcommand with
  `AddCommand`, turns off the generated completion command
  (`CompletionOptions.DisableDefaultCmd = true`), adds a persistent `-v/--verbose` flag that
  switches logging to trace, and has a `RunE` that prints the help.
- `internal/commands/<name>.go`: one `<Name>Cmd() *cobra.Command` constructor per file. Each
  command has its own options struct, filled by its flags, and there are no package-level globals.
  `PreRunE` validates the flags and arguments; `RunE` does the work and sets `cmd.SilenceUsage =
  true` first, because by then the flags are known to be valid and a failure is not a usage error.
- `internal/commands/common_flags.go`: flags several commands share, added by one function.
  `shared.go`: helpers the commands share. Every flag has a long and a short form.
- There is always a `version` command, fed from build info set at release time.
- `internal/config/`: config file and environment loading into a typed struct.
- `internal/<domain>/`: the behaviour, testable without Cobra. No flag parsing and no `os.Exit`.
- Everything is under `internal/`: a CLI is not a library. If other modules need the code, move it
  to its own library module.

### Naming

- The binary is named by its `cmd/<name>/` directory, which matches the repo name.
- Packages: short, lowercase, one word, named for what they do (`scan`, `render`), never `util`.
- Files: lowercase `snake_case.go`, named for the command they hold (`inject.go`, `version.go`).
- Flags are `kebab-case` with a one-letter short form; environment variables are
  `<NAME>_<SETTING>` in upper case.

### Tests, fixtures and generated code

- Unit tests sit next to the code as `<file>_test.go`.
- Command tests drive `run()` or `RootCmd()` in-process, with `SetArgs` and buffers for stdout and
  stderr, and compare output with golden files in `testdata/`. Regenerate the golden files with an
  `-update` flag, never by hand. Exit codes are tested through `run()`.
- Fixtures go in `testdata/` next to the package that reads them.
- Generated code is committed, carries the `// Code generated ... DO NOT EDIT.` header and is named
  `<name>_gen.go`. Build output goes to `bin/` or `dist/`, which are gitignored.
