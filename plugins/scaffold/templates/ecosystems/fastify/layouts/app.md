A Fastify HTTP API service, written as plugins and run by `fastify-cli`.

### Tree

```text
.
├── src/
│   ├── app.ts            the root plugin: default export plus `options`; registers plugins only
│   ├── config.ts         typed, validated config from the environment
│   ├── plugins/          shared infrastructure, each an encapsulated plugin
│   │   └── <name>.ts
│   ├── routes/           one folder per resource; the path mirrors the URL
│   │   └── <resource>/
│   │       ├── index.ts  an encapsulated plugin: the routes and their JSON schemas
│   │       └── index.test.ts
│   └── services/         business logic, free of request and reply
├── migrations/           ordered database migrations
├── __tests__/            integration tests against real services
├── dist/                 build output (gitignored)
├── Dockerfile
├── .env.example          every setting, with safe local defaults
├── package.json
├── tsconfig.json
├── vitest.config.mts
├── eslint.config.mjs
└── Taskfile.yml
```

### What goes where

- There is no `server.ts`. `fastify-cli` loads `dist/app.js`, listens and shuts down. `src/app.ts`
  is the root plugin: a default export and an exported `options` object for the instance. It
  registers plugins and does nothing else: no routes, hooks or logic of its own.
- Every feature is an encapsulated plugin, routes included. Anything another endpoint or service
  could reuse is a plugin in `src/plugins/`, not code inside a route.
- `src/plugins/`: shared infrastructure. A message queue or similar integration comes from
  the owner's published Fastify plugins, registered with the same options shape in every service,
  so a new microservice copies a registration, not code. When the same setup repeats across
  services, it becomes its own published `fastify-<name>` plugin instead of a local copy.
- `src/routes/<resource>/`: one encapsulated plugin per resource, holding its handlers and their
  request and response schemas. A handler validates, calls a service and shapes the reply; it holds
  no business rules.
- `src/services/`: the rules and data access behind them, with no Fastify types.
- `src/config.ts`: the only place that reads `process.env`; it validates at start-up.
- A service is not published to npm (`"private": true`).

### Scripts and logging

- `dev`: `fastify start -w -l trace -P dist/app.js` (watch, trace level, pretty logs).
- `start`: `fastify start -l <level> dist/app.js`, which logs JSON.
- The Taskfile maps `LOG_LEVEL` to `--log-level` and `LOG_FORMAT=console` to `--pretty-logs`.
  Local runs are `trace` with console output; every cluster logs JSON, and production runs at
  `error`.

### Naming

- Folders and files: `camelCase`; a route folder is named for its URL segment (`routes/accounts/`).
- Every route declares a schema; response types come from the schema, not a separate interface.
- Environment variables: `UPPER_SNAKE_CASE`, all listed in `.env.example`, including `LOG_LEVEL`
  and `LOG_FORMAT`.

### Tests, fixtures and generated code

- Tests boot the real app with `build()` from `fastify-cli/helper`, which loads `app.ts` the way
  `fastify start` does, and close it after each test.
- Route tests sit next to the route as `index.test.ts` and use `app.inject()`; no network.
- Integration tests in `__tests__/` run against real dependencies, with fixtures in
  `__tests__/__fixtures__/`.
- Generated clients and types go in `src/generated/`, are committed and rebuilt by a script; never
  edit them by hand. `dist/` is gitignored.
