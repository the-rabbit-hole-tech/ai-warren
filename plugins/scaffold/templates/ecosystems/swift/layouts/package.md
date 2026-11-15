An importable Swift package: the library target sits under `Sources/`, with one target per concept
once it grows.

### Tree

```text
.
├── Package.swift             products, targets and platform minimums
├── Sources/
│   └── <Name>/               the library target; one file per concept
├── Tests/
│   └── <Name>Tests/          Swift Testing tests, one file per source file
├── Examples/<name>/          standalone example packages that depend on this one
├── docs/
├── .swiftlint.yml
├── .swiftformat
└── Taskfile.yaml
```

### What goes where

- `Sources/<Name>/`: the public API users import. Nothing that only tests or examples need.
- One target per concept once a concept outgrows a few files. Split by dependencies too: an
  integration with its own dependencies is its own target, so importing the main library does not
  pull them in.
- Public types are `public` on purpose; everything else stays `internal`.
- `Examples/<name>/`: separate packages that build against the public API only.
- No `Utils` or `Common` targets: name a target for what it holds.

### Naming

- Types and files are `UpperCamelCase`, one primary type per file, the file named for the type.
- The package, product and library target share one `UpperCamelCase` name.
- Swift 6 language mode with strict concurrency; public types are `Sendable` where they can be.

### Tests, fixtures and generated code

- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`) in `Tests/<Name>Tests/`, written
  against the public API.
- Fixtures go in `Tests/<Name>Tests/Fixtures/` and are declared as test resources in
  `Package.swift`.
- Generated code is committed, carries a "do not edit" header and lives in a `Generated/` folder
  of its target. Never edit it by hand.
- `.build/` and `.swiftpm/` are gitignored.
