An importable Go module: the main package sits at the module root, with a sub-package per concept
once it grows.

### Tree

```text
.
├── doc.go                package overview (the godoc landing page) and sub-package map
├── <concept>.go          the public API, one file per concept
├── <concept>_test.go
├── example_test.go       runnable godoc examples
├── errors.go             exported error values and types
├── <concept>/            a sub-package for a concept that outgrew the root
├── <adapter>/            optional sub-package with its own dependencies
├── internal/             unexported code the packages share
├── examples/<name>/      standalone example programs
├── testdata/             test fixtures
├── go.mod
├── Taskfile.yaml
└── .golangci.yml
```

### What goes where

- Root `*.go`: the package users import. Nothing that only tests or examples need.
- The root stays flat while the library is small. When one concept grows past a few files, or the
  root reaches roughly 15 source files, that concept moves to its own `<concept>/` package. The
  root keeps the main entry point (the client or the top-level types) and `doc.go`, which points
  readers to the sub-packages.
- `<concept>/`: one job per sub-package, named for what it holds, never `util`. Concept folders
  are about size and clarity.
- `<adapter>/`: an integration with its own dependencies (tracing, a driver), so importing the
  root package does not pull them in. Adapter folders are about dependencies. Not a place for
  plain helpers.
- `internal/`: unexported code the root and the sub-packages share, hidden from users. Not a
  dumping ground; give each package one job.
- `examples/<name>/`: `package main` programs that build against the public API only.
- No `cmd/` and no `pkg/`: a library has no binary, and the root already is the package.

### Naming

- Package name: short, lowercase, one word, the module name without a `go-` prefix. No `util`,
  `common` or `helpers` packages.
- Files: lowercase `snake_case.go`, named for the concept they hold (`options.go`, `retry.go`).
- Exported names do not repeat the package name (`redis.Client`, not `redis.RedisClient`).
- Constructors are `New` or `New<Type>`; options are functional (`With<Setting>`).

### Tests, fixtures and generated code

- Unit tests sit next to the code as `<file>_test.go`. Black-box tests and examples use
  `package <name>_test`.
- Tests that need a real service live in `integration_test.go` (or `integration_<topic>_test.go`)
  behind `//go:build integration`, so `go test ./...` stays hermetic.
- Fixtures go in `testdata/`, which the Go tool ignores when building.
- Generated code is committed, carries the `// Code generated ... DO NOT EDIT.` header, is named
  `<name>_gen.go`, and is produced by a `//go:generate` line or a Taskfile task. Never edit it by
  hand.
