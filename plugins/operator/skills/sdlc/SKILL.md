---
name: sdlc
description: Use when a new app (microservices or monolith) is started, or when deciding what comes next in its build.
---

# App build cycle

- Every new app of the rabbit hole, microservices or monolith, follows this cycle, in order. App names are placeholders: `<app>` (the mock and web at `<app>.localhost`, the Go test at `<app>-go.localhost`).
- Step 0: all design, branding, mockups and the "plan" repo are done first. Nothing below starts before that.
- Step 1: the web app(s), however many there are, and the mock, locally.
- Step 2: then the web app(s) and the mock in a kind cluster, on one URL.
- Step 3: if there is a demo, run it on the Pi through a Cloudflare tunnel, behind a private link (a 30-day cookie). Docs (the product documentation and the docs site) start getting built from this step on.
- Step 4: the Go code, locally, with its database in the kind cluster (one Postgres, a database and role per service). The Go services run on the Mac, not in the cluster.
- Step 5: once the Go is as mature as the mock, all services go into the kind cluster and are tested there, at `<app>-go.localhost`.
- Step 6: run it on the Pi for final hardware testing.
- Step 7: depending on the app, build the appliance. A Kubernetes-only app builds the Helm chart first, which the appliance needs.
- The mock never drifts, steps 1 to 6: whenever the Go behaviour changes, update the mock and web to match, so the mock stays the reference, including during local Go testing.

```
  0  DESIGN FIRST: branding . mockups . the "plan" repo
     v
  1  WEB(S) + MOCK ........ local
     v
  2  KIND CLUSTER ......... one URL (<app>.localhost)
     v
  3  DEMO ON THE PI ....... Cloudflare tunnel + 30-day private link   [docs start here]
     v
  4  GO CODE, LOCAL ....... database in kind (localhost:5432)
     v        mock never drifts: mock + web updated with every Go change (steps 4 to 6)
  5  ALL SERVICES IN KIND . once the Go is as mature as the mock (<app>-go.localhost)
     v
  6  THE PI ............... final hardware test
     v
  7  APPLIANCE ............ Kubernetes-only app: the Helm chart first
     v
  RELEASE (rc, then stable; the owner publishes)
```

## Example: a shop app

An example only, not a rule for other apps.

- Steps 1 and 2: the mock and web at `shop.localhost`.
- Step 3: the demo at `demo.example.com`; the docs site at `docs.example.com` starts here.
- Step 5: all Go services in kind at `shop-go.localhost`.
