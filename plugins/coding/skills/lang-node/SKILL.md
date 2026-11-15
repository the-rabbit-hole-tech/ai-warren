---
name: lang-node
description: Use when writing or reviewing Node.js or TypeScript code (a repo with package.json or tsconfig.json), setting up lint, or testing and releasing an npm package.
---

# Node.js / TypeScript rules

The global rules come first; this adds Node.js / TypeScript detail and never overrides them.

- **Layout:** follow the repo's layout block (defined in your shared rules repo) once the repo has one. The shared rules repo's npm and Fastify layouts are the reference.
- **Imports:** use path aliases (`@/components`, `@/lib`, `@/server`). Never use relative imports that go up more than one level (no `../../..`). Prefer named exports over default exports.
- **Lint and format:** The org's shared Oxlint and oxfmt config package (named by the org plugin) is the standard linter and formatter: Oxlint lints and oxfmt formats, with no ESLint config or separate Prettier setup. It's always a devDependency. A repo still on an older lint config switches in its own surgical PR that changes nothing else.
- **Before any npm release:** test in a throwaway non-git folder. Run `npm pack`, install the tarball, follow the package's AGENTS.md cold, and check ESM and CJS imports, types, and that a docs recipe compiles.
- **npm package size:** before any npm PR is called done and before any release, build locally and inspect the tarball.
  - Run `npm run build`, then `npm pack --dry-run`, and read the file list and the package and unpacked size.
  - Compare with the last published size (`npm view <pkg> dist.unpackedSize dist.fileCount`) and explain any big jump.
  - Nothing outside the `files` allowlist: no tests, fixtures, source, `.map` files, docs sites or build caches.
  - Then install the packed tarball in a throwaway folder and import it, ESM and CJS, to prove it works.

## Template npm package checks

npm packages from the templates (npm, fastify, storybook) carry three checks in `scripts/`; run them after `npm run build`, and CI runs them on every PR.

- **Contents and ceiling** (`npm run check:pack`): `npm pack --dry-run --json --ignore-scripts` must not ship a `.map` file, TypeScript source, tests, a build cache or a non-runtime folder (`src/`, `test/`, `docs/`, `scripts/`, `coverage/`, `temp/`); every entry point in `main`, `module`, `types` and `exports` must exist; `files` must be set; unpacked size stays under `config.packMaxUnpackedBytes` (250 kB in the template; raise it on purpose in the same PR and say why).
- **Growth against the last release** (`npm run check:pack:growth`, its own `job-pack-growth` workflow): compares with `npm view <pkg> dist.unpackedSize dist.fileCount` for the `latest` tag and fails when either grows by more than `config.packMaxGrowthPercent` (25). Growth under 10,000 bytes or 5 files never fails alone; a never-published package passes with a note. For intended growth add the `pack-size-override` label and say why in the PR body.
- **Install smoke test** (`npm run check:install`): packs, installs the tarball and its required peers in a throwaway folder outside the repo and loads every `exports` subpath as ESM and CJS; it fails on an entry that does not load, loads empty, or whose ESM and CJS names differ. Stylesheet subpaths are resolved, not loaded.
- Source maps are off in the published build (`sourcemap: false`); never turn them on. Always pass `--ignore-scripts` to `npm ci`, `npm install` and `npm pack`: a `prepare` script (husky) resets `core.hooksPath` and bypasses the commit guard.
