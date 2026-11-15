A React component library with Storybook, published to npm.

### Tree

```text
.
├── .storybook/
│   ├── main.ts           story globs and addons
│   ├── preview.ts        global parameters and decorators
│   ├── manager.ts        the Storybook UI settings
│   ├── theme.ts          the Storybook UI theme
│   ├── decorators.tsx    decorators shared by the stories
│   ├── providerWrapper.tsx  wraps every story in the library's providers
│   └── vitest.setup.ts   test environment setup
├── packages/             the library source; only this is built
│   ├── main.ts           the public entry point: named exports of components and their types
│   ├── tokens.css        design tokens
│   ├── components.css    component styles
│   ├── component/
│   │   ├── primitive/<name>/    the smallest building blocks
│   │   ├── component/<name>/    pieces built from primitives
│   │   ├── module/<name>/       composite sections
│   │   ├── widget/<name>/       self-contained interactive pieces
│   │   └── provider/<name>/     context providers
│   ├── pages/<name>/     full pages built from the tiers above
│   └── shared/
│       ├── constants/
│       ├── data/
│       ├── functions/
│       ├── i18n/
│       ├── react/        shared hooks and React helpers
│       └── types.ts
├── stories/
│   ├── home.mdx          docs pages: home, getting started, installation, colors
│   ├── files/<name>.stories.tsx   one story file per component
│   ├── component/<group>/  many stories for one big component
│   ├── pages/            page stories
│   └── fixtures/         data the stories use
├── __tests__/
│   ├── <name>.test.ts    one test file per component
│   └── fixtures/
├── tools/                repo tooling: generators, the story index check, package verification
├── dist/                 library build output (gitignored)
├── storybook-static/     built Storybook site (gitignored)
├── Dockerfile            serves the built Storybook
├── package.json
├── tsconfig.json
├── vite.config.ts        library build and Vitest config
├── eslint.config.mjs
└── Taskfile.yml
```

### What goes where

- `packages/main.ts`: named exports of every public component and its types, plus the imports of
  `tokens.css` and `components.css` so the build ships them. No other code; anything not exported
  here is private.
- `packages/component/<tier>/<name>/`: one component per folder, in the one tier it belongs to.
  Each folder holds `<name>.tsx`, an `index.tsx` barrel, `types.ts` for its props and other types,
  an optional `<name>.module.css`, and subfolders for the parts of a big module.
- `packages/pages/<name>/`: full pages composed from the tiers. `packages/shared/`: constants, data,
  functions, i18n strings and React helpers used across components, with the shared `types.ts`.
- `packages/tokens.css` and `packages/components.css`: the design tokens and the component styles
  the build ships.
- `stories/`: the `*.mdx` docs pages (home, getting started, installation, colors),
  `files/<name>.stories.tsx` with one file per component, `component/<group>/` for the many stories
  of one big component, `pages/` and the `fixtures/` the stories use.
- `.storybook/`: Storybook config only: main, preview, manager, theme, the shared decorators, the
  provider wrapper and the Vitest setup.
- `tools/`: scripts for the repo itself (generators, the story index check, package verification).
  Never shipped.
- Stories and tests live outside `packages/`, so the build ships only library code. `react` and
  `react-dom` are peer dependencies, never bundled. Only `dist/` is published.
- No `legacy/` or `plan/` folders in the repo.

### Naming

- Folders and files are `camelCase` (`packages/component/primitive/button/button.tsx`); the
  component itself is `PascalCase` (`Button`).
- Props types are `I<Name>Properties` (`IButtonProperties`), declared in the component's `types.ts`
  and exported from `packages/main.ts` with the component.
- Story titles follow the tier and the name (`Primitive/Button`); each story is a named export in
  `PascalCase` (`Primary`, `Disabled`).
- CSS class names are prefixed with the library name, so they do not collide in a host app.

### Tests, fixtures and generated code

- Tests live in `__tests__/<name>.test.ts` (`.tsx` when they render JSX), one file per component,
  with Vitest and Testing Library; shared test data goes in `__tests__/fixtures/`. Stories double as
  visual and accessibility checks.
- Story data goes in `stories/fixtures/`, never inside `packages/`.
- Generated tokens or icons are committed and rebuilt by a script in `tools/`; never edit them by
  hand. `dist/` and `storybook-static/` are gitignored.
