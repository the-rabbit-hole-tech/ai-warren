A TypeScript package published to npm as ESM and CJS.

### Tree

```text
.
├── src/
│   ├── index.ts          the public entry point: exports only
│   ├── <module>.ts       one concept per module
│   ├── <module>.test.ts
│   └── <area>/           a group of related modules, with its own index.ts
├── __tests__/            cross-module and integration tests (optional)
├── scripts/              repo tooling: pack, install and size checks
├── docs/                 generated API docs (TypeDoc), not hand-written
├── dist/                 build output (gitignored)
├── package.json
├── tsconfig.json
├── tsdown.config.ts
├── vitest.config.mts
├── eslint.config.mjs
└── Taskfile.yml
```

### What goes where

- `src/index.ts`: re-exports the public API and nothing else. Anything it does not export is
  private, and `package.json` `exports` points only at the built entry.
- `src/<area>/`: modules that change together. Import across areas through their `index.ts`.
- `scripts/`: Node scripts for the repo itself (`checkPack.mjs` and friends). Never shipped.
- `docs/`: TypeDoc output. Write guides in the README or a docs site, not here.
- Only `dist/` is published (`files` in `package.json`): no sources, tests, maps or fixtures.

### Naming

- Package name: the repo name, lowercase `kebab-case`.
- Files: `camelCase.ts` for modules, `PascalCase.ts` for a file whose main export is a class.
- Types and classes are `PascalCase`; functions and variables `camelCase`; constants
  `UPPER_SNAKE_CASE` only for true constants.
- Named exports only; no default exports from the public entry.

### Tests, fixtures and generated code

- Unit tests sit next to the module as `<module>.test.ts` (Vitest).
- Tests that span modules or need a service go in `__tests__/`, with shared helpers in
  `__tests__/__utils__/` and fixtures in `__tests__/__fixtures__/`.
- Generated sources, when any, go in `src/generated/`, are committed and are rebuilt by a script;
  never edit them by hand. Build output (`dist/`) is gitignored.
