# Context budget

What a session loads before its first turn, measured so each phase of ai-warren can show what it
saved. Rows are appended by `tests/context/measure.sh <dir> <label>`.

- **First-turn tokens:** a one-line `claude -p "Reply with OK." --output-format json` run in the
  directory, summing `input_tokens`, `cache_creation_input_tokens` and `cache_read_input_tokens`.
  That is the whole first prompt: the system prompt, the tool and MCP tool lists, skill listings,
  hook context and the memory files. It's an upper bound for the rules, not the rules alone.
- **Memory files and bytes:** every memory file the session loads, following `@` imports:
  `~/.claude/CLAUDE.md` and its imports, `~/.claude/rules/*.md`, each `CLAUDE.md` from the
  directory up to the home folder with its imports, and the project's auto memory `MEMORY.md`.
  Language files load only when read, so they aren't counted.

## Baseline (before any plugin)

Measured with a full personal rule stack linked into `~/.claude/`. At roughly 4 bytes a token, the
memory files alone are about 24k to 27k tokens of each session's 66k to 70k first-turn tokens
[Likely; the split comes from file sizes, not from the API].

Memory files for a repo session, in bytes (the shape, not a fixed set of files):

| File | Bytes |
|---|---|
| `~/.claude/CLAUDE.md` (its imports are counted below) | ~150 |
| common rules file | ~7,000 |
| host file | ~12,000 |
| package catalog (`refresh-projects.sh` output) | ~6,000 |
| topic rules folder (about a dozen files) | ~63,000 |
| org `CLAUDE.md` and the org file it imports | ~7,000 |
| repo `CLAUDE.md` | ~8,000 |
| **Total** | **~104,000** |

A repo with a larger `CLAUDE.md` or an org file of a different size shifts the total by a few
thousand bytes. A session started at the code root has no org or repo file but loads its auto
memory `MEMORY.md`.

`claude plugin details warren@ai-warren` reports an always-on cost of about 0 tokens, because it
counts skills and agents, not hook output. The warren text it injects at session start is about
2,000 characters, roughly 500 tokens [Likely].

First-turn runs from `tests/context/measure.sh` are appended here, one row per run:

| Date | Label | Directory | First-turn tokens | Memory files | Memory bytes |
|---|---|---|---|---|---|

## Projected cost with the plugins

What the rule stack costs every session once the plugins replace it. The old stack is the global
file, the topic rules, the host file and the package catalog; the repo, org and auto memory files
are the same before and after, so they're left out of both sides.

The after side can't be a first-turn run in a throwaway config folder: it has no sign-in. So it's
projected with `tests/context/projected.sh <host-file>` on a tree with every plugin merged: each
plugin is installed in a throwaway config folder and `claude plugin details` gives its always-on
cost (the skill listings), plus the warren text injected at session start and a trimmed host file,
at about 4 bytes a token. The before side uses the same 4-bytes estimate.

| Rule stack | Before | After, full machine | After, contributor |
|---|---|---|---|
| Global file and topic rules | ~70,000 bytes, ~17,500 tokens | | |
| Host file | ~12,000 bytes, ~3,000 tokens | ~4,000 bytes, ~1,000 tokens | ~4,000 bytes, ~1,000 tokens |
| Package catalog | ~6,400 bytes, ~1,600 tokens | read on demand | read on demand |
| warren text (session start) | | ~2,000 bytes, ~500 tokens | ~500 tokens |
| Skill listings | | ~2,700 tokens | ~1,350 tokens (warren, github, coding) |
| **Total** | **~88,000 bytes, ~22,000 tokens** | **~4,200 tokens, about 80% less** | **~2,900 tokens, about 87% less** |

The optional secrets plugin adds about 115 tokens. The skill bodies load only when a step needs
them: about 20,000 tokens across all plugins, paid per use rather than every turn. Every listed
description together stays under the 12,000-character budget `tests/skills/skill-format.test.sh`
holds them to.
