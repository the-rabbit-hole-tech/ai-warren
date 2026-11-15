A long-running Rust service (HTTP or gRPC API, worker or consumer).

### Tree

```text
.
├── src/
│   ├── main.rs           entry point: load config, wire, run, shut down
│   ├── lib.rs            the library root, so tests can build the app
│   ├── config.rs         typed config from the environment
│   ├── server/           transport: routes or gRPC handlers, middleware
│   ├── <domain>/         business logic, one module per domain area
│   └── store/            persistence and external clients behind traits
├── migrations/           ordered SQL migrations
├── proto/                protobuf sources, when the service speaks gRPC
├── tests/                integration tests that start the app
│   ├── <feature>.rs
│   └── fixtures/         fixture files
├── Dockerfile
├── .env.example          every setting, with safe local defaults
├── Cargo.toml
├── Cargo.lock            committed
├── rust-toolchain.toml   pinned toolchain
├── Taskfile.yml
└── README.md
```

### What goes where

- `main.rs`: builds the runtime and dependencies, starts the server and handles shutdown signals.
  No logic.
- `lib.rs`: exposes a function that builds the app from a config, so tests start it on a random
  port.
- `config.rs`: the only place that reads the environment; it validates at start-up.
- `server/`: routing, extraction and error mapping. It calls the domain and holds no business
  rules.
- `<domain>/`: the rules, free of transport and database types.
- `store/`: queries and clients behind traits the domain defines.
- `migrations/`: numbered, forward-only files. Never edit one that has shipped.

### Naming

- Crate name: the repo name in `kebab-case`.
- Modules and functions `snake_case`; types and traits `PascalCase`; constants
  `UPPER_SNAKE_CASE`.
- Module files are `<name>.rs`, with a `<name>/` folder beside them for submodules (no `mod.rs`).
- Environment variables: `UPPER_SNAKE_CASE`, all listed in `.env.example`, including `LOG_LEVEL`
  and `LOG_FORMAT`.

### Tests, fixtures and generated code

- Unit tests sit in the same file under `#[cfg(test)] mod tests`.
- Integration tests in `tests/` start the app from `lib.rs` against real dependencies, with
  fixtures in `tests/fixtures/`.
- Code generated from `proto/` is produced by `build.rs` into `OUT_DIR` and never committed.
  `target/` is gitignored.
