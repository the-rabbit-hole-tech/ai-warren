A React single-page app built with Vite.

### Tree

```text
.
├── index.html            the Vite entry document
├── public/               static files served as-is (favicon, robots.txt)
├── src/
│   ├── main.tsx          mounts the app: providers and the router
│   ├── App.tsx           the root component and routes
│   ├── pages/            one component per route
│   ├── components/       reusable UI, one component per file
│   │   ├── <Component>.tsx
│   │   └── <Component>.test.tsx
│   ├── features/<name>/  a feature's components, hooks and state together
│   ├── hooks/            shared custom hooks
│   ├── lib/              framework-free helpers and API clients
│   ├── assets/           images and fonts imported by code
│   ├── styles/           global styles and design tokens
│   └── setupTests.ts     test environment setup
├── dist/                 build output (gitignored)
├── package.json
├── tsconfig.json
├── tsconfig.app.json
├── tsconfig.node.json
├── vite.config.ts        build and Vitest config
├── eslint.config.mjs
└── Taskfile.yml
```

### What goes where

- `src/pages/`: route-level components that fetch data and compose features. Not reused elsewhere.
- `src/components/`: presentational pieces used in more than one place. No data fetching.
- `src/features/<name>/`: code that belongs to one feature; promote a piece to `components/` or
  `hooks/` once a second feature needs it.
- `src/lib/`: plain TypeScript (API clients, formatting). No React imports.
- `public/`: files that need a fixed URL. Anything imported by code goes in `src/assets/` so Vite
  hashes it.
- Configuration comes from `import.meta.env.VITE_*`; never put secrets there, it ships to the
  browser.

### Naming

- Components and their files are `PascalCase` (`UserCard.tsx`), one component per file.
- Hooks are `useCamelCase.ts`; other modules `camelCase.ts`; folders `camelCase`.
- Named exports; a page may default-export only when the router lazy-loads it.

### Tests, fixtures and generated code

- Tests sit next to the component as `<Component>.test.tsx` (Vitest and Testing Library), set up by
  `src/setupTests.ts`.
- Mock data and fixtures go in `src/test/` (or `__fixtures__/` beside the feature that uses them).
- Generated API clients and types go in `src/generated/`, are committed and rebuilt by a script;
  never edit them by hand. `dist/` is gitignored.
