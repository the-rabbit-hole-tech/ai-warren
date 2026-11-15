# __REPO_NAME__ 🎨

> 🧭 __DESCRIPTION__

A React + TypeScript UI component library. Components are documented and
developed in [Storybook](https://storybook.js.org), the library is published to
npm, and the built Storybook catalog can be served as a static site behind
nginx.

## 📦 Install

```bash
npm install __REPO_NAME__
```

`react` and `react-dom` are peer dependencies; install them in the consuming
app.

## 🚀 Usage

```tsx
import "__REPO_NAME__/style.css";
```

Import the stylesheet once in the consuming app, then import components by
name from `__REPO_NAME__` as they are added.

## 🛠 Develop

```bash
npm install
npm run storybook        # Storybook dev server on http://localhost:6006
npm run build            # type-check + vite library build -> dist/
npm run build-storybook  # static Storybook catalog -> storybook-static/
npm test                 # vitest (jsdom + Testing Library)
npm run lint             # eslint (the formatter; no Prettier)
npm run typecheck        # tsc --noEmit
npm run docs             # typedoc -> docs/ (warnings fail the build)
```

The repo starts with the folder structure only, and no components. Add a
component under `packages/component/<tier>/<name>/` (tiers: `primitive`,
`component`, `module`, `widget`, `provider`), export it and its props type
from `packages/main.ts`, write its story in `stories/files/<name>.stories.tsx`
and its tests in `__tests__/`. Stories and tests stay outside `packages/`, so
the library build ships only library code.

## 🐳 Hosting the Storybook catalog (nginx + Docker)

The built Storybook bundle is a static site, served by a multi-stage image: a
Node stage runs `build-storybook`, then `nginx:alpine` serves the output.

```bash
docker build -t __REPO_NAME__-storybook .
docker run --rm -p 8080:80 __REPO_NAME__-storybook
# open http://localhost:8080
```

`nginx.conf` long-caches fingerprinted assets, never caches the HTML entry
points, falls back to `index.html` for deep links, and exposes `/healthz`.

> Publishing: this image isn't pushed to a registry yet. Once the catalog has a
> hosting target, add the shared multi-arch image workflow
> (`job-image-publish.yaml`), which publishes it to GHCR for linux/amd64 and
> linux/arm64 on every release.

## ⚖️ License

__LICENSE__ (c) __YEAR__ __AUTHOR__
