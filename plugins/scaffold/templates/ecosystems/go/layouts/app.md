A long-running Go service (HTTP or gRPC API, worker or consumer).

### Tree

```text
.
├── cmd/server/
│   └── main.go           entry point: load config, wire the helpers, run, shut down
├── internal/
│   ├── config/           typed settings from the environment
│   ├── server/           transport: routes or gRPC handlers
│   ├── <domain>/         business logic, one package per domain area
│   └── store/            queries behind interfaces the domain owns
├── migrations/           ordered SQL migrations
├── proto/                protobuf sources, when the service speaks gRPC
├── gen/                  code generated from proto/ or a schema
├── deployments/          Helm chart or manifests, when the repo ships them
├── testdata/             test fixtures
├── Dockerfile
├── .env.example          every setting, with safe local defaults
├── go.mod
├── Taskfile.yaml
└── .golangci.yml
```

### What goes where

- Shared infrastructure is not written from scratch. Logging and trace correlation, database and
  cache connections, message brokers, coded errors and seed data come from the owner's
  published helper packages wherever one covers the job (see the owner's package catalog for each
  package and its version). The service configures and wires them; it does not wrap or
  re-implement them. When no package covers a need, report it as a gap instead of building a
  one-off.
- `cmd/server/`: only `main.go`. It builds the dependencies from the helper packages, starts the
  server and handles signals. A second binary (a worker, a migration runner) gets its own
  `cmd/<name>/`.
- `internal/config/`: one struct filled from environment variables and validated at start-up,
  holding the settings each helper package takes. No config reads anywhere else.
- `internal/server/`: request decoding, auth and turning coded errors into responses. It calls the
  domain; it holds no business rules.
- `internal/<domain>/`: the rules, free of transport and database types, so they test without
  either.
- `internal/store/`: the service's own queries, run on the connection the helper package provides.
  Sub-packages per backend (`store/postgres/`, `store/memory/`) when there is more than one.
- `migrations/`: numbered, forward-only files (`0001_create_users.up.sql`). Never edit a migration
  that has shipped; add a new one.
- `proto/` and `gen/`: sources in `proto/`, generated output only in `gen/`.

### Naming

- Packages: short, lowercase, one word, named for the domain (`billing`, `session`), never `util`
  or `models`.
- Files: lowercase `snake_case.go`, one concept per file (`handler.go`, `repository.go`).
- Environment variables: `UPPER_SNAKE_CASE`, listed in `.env.example`. `LOG_LEVEL` and `LOG_FORMAT`
  are always there.
- Interfaces are declared by the package that uses them, not the one that implements them.

### Tests, fixtures and generated code

- Unit tests sit next to the code as `<file>_test.go`.
- Tests that need real infrastructure (database, broker) are behind `//go:build integration`, or in
  `test/e2e/` when they drive the whole running service.
- Fixtures go in `testdata/` next to the package that reads them.
- Generated code lives in `gen/` (or `<name>_gen.go`), is committed, carries the
  `// Code generated ... DO NOT EDIT.` header and is rebuilt by a Taskfile task. Never edit it by
  hand.
