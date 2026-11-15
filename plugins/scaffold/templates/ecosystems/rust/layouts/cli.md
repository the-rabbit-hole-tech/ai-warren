A Rust command-line tool: one crate with a thin binary over a library target.

### Tree

```text
.
├── src/
│   ├── main.rs           entry point: parse args, call the library, set the exit code
│   ├── lib.rs            the library root: modules and public items
│   ├── cli.rs            argument definitions (clap derive)
│   ├── commands/         one module per subcommand
│   │   └── <command>.rs
│   └── <module>.rs       the work itself
├── tests/                integration tests that run the binary
│   ├── <feature>.rs
│   └── fixtures/         fixture files and expected output
├── benches/              optional benchmarks
├── Cargo.toml
├── Cargo.lock            committed: this crate ships a binary
├── rust-toolchain.toml   pinned toolchain
├── Taskfile.yml
└── README.md
```

### What goes where

- `main.rs`: a few lines that parse arguments and call into `lib.rs`, mapping errors to an exit
  code. No logic.
- `lib.rs` and its modules: the behaviour, usable and testable without the binary.
- `cli.rs`: the clap types only. Commands receive plain values, not clap structs, where practical.
- `commands/`: one subcommand each; it calls library functions and formats output.
- A workspace (`crates/<name>/`) only when the project really has several crates.

### Naming

- Crate and binary name: the repo name in `kebab-case`; the library is used as `snake_case`.
- Modules and functions `snake_case`; types and traits `PascalCase`; constants
  `UPPER_SNAKE_CASE`.
- Module files are `<name>.rs`, with a `<name>/` folder beside them for submodules (no `mod.rs`).

### Tests, fixtures and generated code

- Unit tests sit in the same file under `#[cfg(test)] mod tests`.
- Integration tests in `tests/` run the built binary (`assert_cmd`) against `tests/fixtures/` and
  snapshot the output.
- Code generated at build time comes from `build.rs` into `OUT_DIR` and is never committed.
  Checked-in generated code goes in `src/generated/`, with a header saying how to rebuild it.
  `target/` is gitignored.
