# __REPO_NAME__ ⚡

> 🔌 __DESCRIPTION__

A Fastify v5 plugin, authored with [`fastify-plugin`](https://github.com/fastify/fastify-plugin)
and shipped as dual ESM/CJS with TypeScript types.

## 📦 Install

```bash
npm install __REPO_NAME__
```

`fastify` (`^5.8`) is a peer dependency; install it in the host app.

## 🚀 Usage

```ts
import Fastify from "fastify";
import example from "__REPO_NAME__";

const app = Fastify();
await app.register(example, { greeting: "Hi" });
await app.ready();

app.greet("world"); // "Hi, world!"
```

The plugin decorates the instance (`greet`) and augments the `FastifyInstance`
type, so the decorator is fully typed in the host app.

## 🛠 Develop

```bash
npm install
npm run build      # tsdown -> dist (esm + cjs + d.ts)
npm test           # vitest (registers the plugin on fastify() and asserts via inject)
npm run lint       # eslint + prettier
npm run typecheck  # tsc --noEmit
npm run docs       # typedoc -> docs
```

## 🌱 Grow into an app (optional)

The published package is just the plugin (`src/index.ts`). To run it as a
service, this template also ships an optional app path that is intentionally
kept OUT of the published entry:

- `src/app.ts` registers everything under `src/plugins/` via
  [`@fastify/autoload`](https://github.com/fastify/fastify-autoload).
- `src/plugins/example.ts` registers this package's own plugin and exposes a
  route that uses its decorator.

Run it with [`fastify-cli`](https://github.com/fastify/fastify-cli):

```bash
npm run app        # boot src/app.ts
npm run app:dev    # boot with watch + reload
```

Only `src/index.ts` is bundled into `dist/`, so the app path never ships to npm.

## ⚖️ License

__LICENSE__ (c) __YEAR__ __AUTHOR__
