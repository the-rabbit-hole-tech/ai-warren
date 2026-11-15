A long-running Node.js service (API, worker or consumer) written in TypeScript.

### Tree

```text
.
├── src/
│   ├── main.ts           entry point: load config, wire, start, shut down
│   ├── config.ts         typed, validated config from the environment
│   ├── server/           transport: routes, middleware, error mapping
│   ├── <domain>/         business logic, one folder per domain area
│   │   ├── service.ts
│   │   └── service.test.ts
│   └── store/            persistence and external clients
├── migrations/           ordered database migrations
├── __tests__/            integration tests against real services
├── scripts/              repo tooling
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

- `src/main.ts`: builds the dependencies, starts listening and handles `SIGTERM`. No logic.
- `src/config.ts`: the only place that reads `process.env`; it validates at start-up and fails
  fast.
- `src/server/`: request parsing, auth, logging and error responses. It calls the domain and holds
  no business rules.
- `src/<domain>/`: the rules, free of HTTP and database types.
- `src/store/`: queries and third-party clients behind small interfaces the domain uses.
- `migrations/`: numbered, forward-only files. Never edit one that has shipped.
- A service is not published to npm (`"private": true`).

### Naming

- Folders and files: `camelCase`. Inside a domain folder, files are named for their role
  (`service.ts`, `routes.ts`, `repository.ts`).
- Types and classes are `PascalCase`; functions and variables `camelCase`.
- Environment variables: `UPPER_SNAKE_CASE`, all listed in `.env.example`, including `LOG_LEVEL`
  and `LOG_FORMAT`.

### Tests, fixtures and generated code

- Unit tests sit next to the module as `<module>.test.ts`.
- Integration tests in `__tests__/` run against real dependencies (containers), with fixtures in
  `__tests__/__fixtures__/`.
- Generated clients and types go in `src/generated/`, are committed and rebuilt by a script; never
  edit them by hand. `dist/` is gitignored.
