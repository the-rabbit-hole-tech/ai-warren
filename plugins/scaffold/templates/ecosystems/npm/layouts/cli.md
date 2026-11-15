A Node.js command-line tool written in TypeScript and installed from npm.

### Tree

```text
.
├── src/
│   ├── cli.ts            entry point: parse argv, dispatch, set the exit code
│   ├── commands/         one module per command
│   │   └── <command>.ts
│   ├── lib/              the work itself, free of argv and console output
│   │   └── <module>.ts
│   └── index.ts          programmatic API, when the tool offers one
├── __tests__/            end-to-end tests that run the built CLI
├── scripts/              repo tooling
├── dist/                 build output (gitignored)
├── package.json          "bin" points at dist/cli
├── tsconfig.json
├── tsdown.config.ts
├── vitest.config.mts
├── eslint.config.mjs
└── Taskfile.yml
```

### What goes where

- `src/cli.ts`: argument parsing and wiring only, with the `#!/usr/bin/env node` banner added at
  build time. No business logic.
- `src/commands/`: one command each. It reads options, calls `src/lib/`, and formats the output.
- `src/lib/`: the behaviour, testable without spawning a process. No `process.exit` and no direct
  `console` writes; return values or throw typed errors.
- `src/index.ts`: only when other code should call the tool as a library.

### Naming

- Package and binary name: the repo name, lowercase `kebab-case`.
- Command modules are named for the command (`init.ts`, `check.ts`).
- Files: `camelCase.ts`; flags are `--kebab-case`; environment variables `<NAME>_<SETTING>` in
  upper case.

### Tests, fixtures and generated code

- Unit tests sit next to the module as `<module>.test.ts`.
- End-to-end tests in `__tests__/` run the built binary against fixtures in
  `__tests__/__fixtures__/` and compare output with snapshot files.
- Generated sources, when any, go in `src/generated/`, are committed and rebuilt by a script.
  `dist/` is gitignored.
