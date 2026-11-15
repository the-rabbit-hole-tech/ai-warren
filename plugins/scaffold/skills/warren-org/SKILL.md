---
name: warren-org
description: Use when the owner runs /scaffold:warren-org to set up a new org.
disable-model-invocation: true
---

# Set up a new org

An org plugin holds one owner's own rules on top of the base. Build it from the shipped template:

1. Ask for the GitHub owner (an org or a user) and the copyright holder for new repos (default "The <owner> Authors").
2. Run `warren-new-org-plugin <owner> --out <new folder> --author "<holder>"` in a folder outside any other repo. It writes a marketplace named for the lowercased owner and a plugin named `warren-org-<owner>`, with an example rules skill and a `scaffold/scaffold.conf` (see this plugin's README for the keys).
3. Create the GitHub repo for it with scaffold:new-repo (a private repo is fine to start), push, then install it: `claude plugin marketplace add <owner>/<repo>` and `claude plugin install warren-org-<owner>@<owner> --scope user`.
4. Check with `warren-repo-ready` in one of the owner's repos: it prints `ready` when the plugin is installed and enabled.

The naming rule matters: the plugin name starts with `warren-` and the marketplace name is the GitHub owner in lower case. Org and personal plugins carry no version field and track their default branch; only the ai-warren base is versioned and released.
