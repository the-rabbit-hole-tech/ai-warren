# rust (stub)

Planned ecosystem. No template content yet because there is no concrete Rust setup to standardize
on. When a real Rust project exists, fill in `ecosystems/rust/template/` following the same model as
the other ecosystems:

- `Cargo.toml`, `src/lib.rs` (or `main.rs`), a test
- `.github/workflows/` mirroring the others: test (cargo fmt --check, clippy, cargo test),
  release-drafter, require-label
- `.gitignore` (`/target`, `plan/`)
- token files using `__OWNER__`, `__REPO_NAME__`, `__DESCRIPTION__`, `__AUTHOR__`, `__YEAR__`

Then new Rust repos come from `scaffold/new-repo.sh <name> rust`, like every other ecosystem, with
the base topics from `ecosystems/rust/topics`.
The shared governance layer (hooks, GitHub templates, gitleaks) composes in automatically.
