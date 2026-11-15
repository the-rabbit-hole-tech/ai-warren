---
name: reuse
description: Use when about to build anything new, to check what already exists (templates, the package catalog) and reuse it; also when creating or updating a product template repo.
---

# Reuse before building

## Product templates
- When a product proves a base worth reusing, it's extracted into a template repo in your org, named `template-<type>-<name>` (for example `template-go-service`, `template-docs-site`). This applies to every product the org builds.
- A template keeps the structure and wiring only: layout, shared frame, consent gate, deploy and checks. It carries no product's brand, tokens or copy.
- Truly generic only: a template holds what every product shares, and nothing one product does its own way. `template-go-service` holds the layout, build and checks for every Go service. Each product's own customisation lives in that product's own repo, never in the template and never in the product's application code.
- Kept up to date: when a product improves or fixes a generic part, the same change goes into its template in that wave. A template that falls behind its products is a bug.
- A new product starts by cloning the template and adding its own brand and tokens. It never copies straight from another product.
- A fix to the base goes into the template, and each product that came from it gets the same fix in its own PR.
- Reuse goes through a `template-<type>-<name>` repo in your org or a shared package. The templates and the package catalog are the reuse catalog.

## Shared pieces
- **Anything used in two or more places becomes one shared component, helper or template piece, and every use reuses it. Never copy it.** The second use is the trigger: pull the piece out then, don't wait for a third copy.
- Inside a product, a UI element is one shared component, a function is one shared helper, and a repeated block of config, workflow or scaffold is one template piece. Each lives where the product keeps shared code, not in the first place that needed it.
- Across products, the piece goes into a `template-<type>-<name>` repo (above) or a shared package (scaffold:helper-repo).
- Before adding a second copy, find the existing piece. If it nearly fits, extend it, don't fork it.

## Lessons
- **If the owner already built it once, reuse it; never reinvent the wheel.** Before writing any piece, look for where the owner's code already solves it (another product, an earlier repo, a helper package) and reuse the proven design and fixes. Don't copy it straight: make it the product's own, fitted to that product (its names, structure and behaviour), so each product stays unique, and remove the attribution of the project it came from (no copyright line, port note or NOTICE credit for that project; the original-author credit stays). Tokens are cheap; rebuilding and re-debugging costs more.
