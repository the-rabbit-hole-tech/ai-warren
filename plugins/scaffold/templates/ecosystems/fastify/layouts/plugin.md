A Fastify plugin published to npm (wrapped with `fastify-plugin`).

### Tree

```text
.
├── src/
│   ├── index.ts          the published plugin: options, decorators, hooks
│   ├── index.test.ts
│   ├── <module>.ts       internals the plugin uses, one concept per module
│   ├── app.ts            optional: runnable app for local development
│   └── plugins/          optional: plugins autoloaded by app.ts
├── __tests__/            tests that boot a Fastify instance end to end
├── scripts/              repo tooling: pack, install and size checks
├── docs/                 generated API docs (TypeDoc)
├── dist/                 build output (gitignored)
├── package.json
├── tsconfig.json
├── tsdown.config.ts
├── vitest.config.mts
├── eslint.config.mjs
└── Taskfile.yml
```

### What goes where

- `src/index.ts`: the default export (`fp(plugin, { fastify: "5.x", name })`), the options type and
  the `declare module "fastify"` augmentation for every decorator it adds.
- `src/<module>.ts`: logic the plugin wraps, testable without Fastify where it can be.
- `src/app.ts` and `src/plugins/`: a development harness only. tsdown bundles `src/index.ts`, so
  they are never published.
- Only `dist/` is published: no sources, tests, maps or fixtures.

### Naming

- Package name: `fastify-<name>`, lowercase `kebab-case`. The plugin's `name` in `fp()` matches it.
- Decorators are `camelCase` and namespaced by one property (`fastify.<name>.send()`), so they do
  not collide with other plugins.
- Files: `camelCase.ts`; types and classes `PascalCase`.

### Tests, fixtures and generated code

- Unit tests sit next to the module as `<module>.test.ts`.
- Tests that register the plugin on a real instance use `fastify.inject()` and live in
  `__tests__/`, with helpers in `__tests__/__utils__/` and fixtures in `__tests__/__fixtures__/`.
- Generated sources, when any, go in `src/generated/`, are committed and rebuilt by a script.
  `dist/` is gitignored.
