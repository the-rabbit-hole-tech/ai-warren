# __OWNER__ warren rules

An org plugin for the [ai-warren](https://github.com/the-rabbit-hole-tech/ai-warren) base. It holds
the rules that are yours, as skills, and the `scaffold/` values for new repos.

## Install

```bash
claude plugin marketplace add __OWNER__/<this-repo>
claude plugin install warren-org-__OWNER_LOWER__@__OWNER_LOWER__ --scope user
```

## Why it is named this way

The base finds an owner's plugin by name, so keep both parts:

- the plugin name starts with `warren-` (here `warren-org-__OWNER_LOWER__`);
- the marketplace name is the GitHub owner in lower case (here `__OWNER_LOWER__`).

When a repo's `origin` is `github.com/__OWNER__/...`, `warren-repo-ready` looks for an installed,
enabled plugin matching `warren-*@__OWNER_LOWER__`. No such plugin is fine: the base rules still
apply, and the session says the owner's rules are not loaded.

## Write your rules

1. Edit `plugins/warren-org-__OWNER_LOWER__/skills/rules/SKILL.md`, or add a folder per step under
   `skills/` (each with a `SKILL.md` whose `description` starts with "Use when").
2. Edit `plugins/warren-org-__OWNER_LOWER__/scaffold/scaffold.conf` for your copyright holder,
   licence and operator handle.
3. Check it: `claude plugin validate plugins/warren-org-__OWNER_LOWER__`.

An org plugin carries no version field and tracks its default branch. Never put a rule that is not
yours in it, and never put a secret in it.
