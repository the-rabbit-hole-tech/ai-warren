# Pre-push scrub gate

`_dispatch` runs `scrub/gate.py` on every `pre-push`, after the identity check and
before chaining to `guard.chainPath` or `.git/hooks`. It scans only what is new to the remote:
each outgoing commit's added lines (merges through remerge-diff, so only what the merge itself
adds), its message, annotated tag text, and for org remotes paths, binary string runs and ref
names. Any finding blocks the push. Any error blocks it too: the gate fails closed.

## Layers

| Applies to | What runs | Source |
|---|---|---|
| every push | secret patterns over added lines and messages; attribution trailers in messages | `patterns.txt` |
| repos with `.claude/hooks/forbidden-text.txt` (governance installed) | the AI-tell list over added lines and messages, with the governance exemptions (`CLAUDE.md`, `.claude/`, `governance/`, workflows, `*forbidden-text.txt`) | `scrub/forbidden-text.txt`, shipped with the gate (the same list the command guard uses); when `git config --global guard.scrubHubPath` names a clone of the shared rules repo, that clone's `origin/main:governance/claude/hooks/forbidden-text.txt` instead. A missing, unreadable or empty list blocks the push |
| remotes with a path segment named in `orgs.conf` or the local org table | the org scanner's `scrub.py identifiers` (private IPs, emails, home paths, host names, provenance) plus the local term lists; outgoing judged by `git ls-remote` | the scanner repo named by `SCRUB_ORG_SCANNER_URL` or `git config --global guard.scrubScannerUrl`, fetched into `~/.cache/git-scrub/` and read from `origin/main` on every scan; `orgs.conf` and the local org table; `~/.config/warren/terms/<name>-terms.txt` |

The org table is the plugin's `orgs.conf` (empty as shipped) plus your own local table,
`~/.config/warren/scrub-orgs.conf` (`SCRUB_ORGS_FILE` moves it), in the same format. The local table
sits outside the folder `warren-guard-sync` manages, so plugin updates never touch it. A local row
replaces the plugin's row for the same segment. A missing local table is fine; one that can't be
read blocks the push.

A repo named `plan` under an org segment runs only the `forbidden` list. Findings print `file:line`, the
commit and the rule, with the value masked.

## Allowing something

- Known fake secret on one line: put `scrub:allow=secret` on that line.
- Org identifier on one line: `scrub:allow=<class>` (scrub.py; never honoured in messages or paths).
- AI-tell in a repo's Markdown docs: list the exact pattern in the repo's
  `.github/docs-allowed-forbidden-text.txt` (a shared rules repo convention).
- Generated code, vendored files and known test addresses, which can't carry a marker: an entry in
  the repo's reviewed allowlist, `.github/scrub-allow.txt`. See below.
- Term-list hits have no allow: reword.
- Per-clone settings (`guard.scrubAllowPath`, `guard.scrubAllowDomain`) still work, but nobody reviews
  them and they don't travel with the repo. Agents never set them, not even for a moment to get a push
  through: a blocked push is reported, and what should pass goes into the allowlist through a PR.

### The repo allowlist (`.github/scrub-allow.txt`)

The same file the org CI reads (the org scanner's README has the full format):

```text
# <reason>
<class> <exact value> <path glob>
<class> <exact value> <path glob>  # <reason>
```

- **Classes:** `ai-tell` (the shared AI-tell list, this gate only) and the org scanner's `private-ip`,
  `email`, `home-path`, `fqdn`. `secret` is refused; so is anything else.
- **Value:** exactly the matched text, case included, no wildcards. `%20` is a space and `%XX` any
  byte, so an `ai-tell` phrase is written encoded and the list never trips the AI-tell layer itself.
- **Glob:** `fnmatch` on the repo path; `*` crosses `/`. A glob of only wildcards is refused.
- **Where:** added lines of files only, never commit messages, tag text, ref names, paths or binary
  string runs.
- **Base side only:** the gate reads the file at the commit `git ls-remote --symref <remote> HEAD`
  names as the remote's default branch, never from what's being pushed, so an entry counts only
  once its own PR is merged. It reads it only when a finding it could cover turns up. No file there
  is an empty list. That tip missing from the clone (`git fetch` first), an unreachable remote, or
  a malformed line blocks the push.
- **Org remotes:** identifier entries go through the org scanner's own matcher, the one CI runs. An
  org scanner too old to have it blocks the push when the list has identifier entries.
- Each honoured entry prints as `scrub gate: allowed by .github/scrub-allow.txt@<tip>:<line> (<entry>)`.

## Files

- `gate.py`: the gate. `patterns.txt`: secret and attribution patterns. `orgs.conf`: org table (empty template).
- `~/.config/warren/scrub-orgs.conf`: your local org table, same format, outside the synced folder.
- `~/.config/warren/terms/<name>-terms.txt` (the names `orgs.conf` lists): local only (`SCRUB_TERMS_DIR` moves the folder) (dir 700, files 600).
  Never copy them into a repo. A missing or empty list blocks every org push (fails closed).
- `~/.cache/git-scrub/`: the dedicated clone of the org scanner. Safe to delete; it re-clones.
- `git config --global guard.scrubHubPath <path>` (optional): a local clone of the shared rules repo whose
  `governance/claude/hooks/forbidden-text.txt` on `origin/main` replaces the shipped AI-tell list.
  Leave it unset to use the list that ships with the gate.
- `SCRUB_TERMS_DIR`, `SCRUB_CACHE_DIR`: override those two paths, for the tests only.
- `../test/scrub.test.sh [hooks-dir]`: the tests (throwaway repos, `-c core.hooksPath`, needs network,
  reads the term lists from `SCRUB_TERMS_DIR`). The org allowlist cases use the org scanner's
  `origin/main`; `SCRUB_TEST_SCANNER=<repo>@<rev>` runs them against another one (a PR branch).
- `../test/install.test.sh`: the tests for `../install.sh`, against a throwaway hooks dir, HOME and git config. It gives the same result from the checkout or through the installed `~/.config/git/hooks` link.
