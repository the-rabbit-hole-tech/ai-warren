---
name: lang-helm
description: Use when writing or reviewing a Helm chart (a repo with Chart.yaml): appVersion, umbrella charts and their dependencies, and fixing an upstream chart.
---

# Helm / Kubernetes rules

The global rules come first; this adds Helm / Kubernetes detail and never overrides them.

- **Layout:** follow the repo's layout block (defined in your shared rules repo) once the repo has one.
- A chart for an already-released app keeps `appVersion` at that app's released version.
- Umbrella charts the owner releases (more than one app) are exempt: their `appVersion` is the umbrella's own.
- Umbrella charts pull upstream charts in as dependencies and don't copy or extract their contents, unless something has to be fixed.
- When an upstream chart needs a fix, propose it to the owner first. On a Yes, file the upstream issue and, if time allows, write the PR from a fork (`_forks/<repo>` under the code root, topic `forked`). The fork work follows the upstream contributing guide plus the global identity, voice and no-attribution rules.
- **Postgres on Kubernetes is always `Bugs5382/helm-postgres-ha`.** CloudNativePG (CNPG) is never used, proposed or installed, in any design, chart, plan or brief; replace any existing mention.
