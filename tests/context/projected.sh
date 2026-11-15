#!/usr/bin/env bash
# Projects what the ai-warren plugins add to every session, without a live config or a sign-in.
#   tests/context/projected.sh <host-file> [plugin ...]
# Installs the plugins from this tree's marketplace into a throwaway config folder, reads each
# one's always-on cost from `claude plugin details` (skill listings and the like), and adds the
# warren text injected at session start and the host file, at about 4 bytes a token. The default
# plugins are an OPS machine's: warren github coding operator design handoff scaffold.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd -P)
host=${1:?usage: projected.sh <host-file> [plugin ...]}; shift
plugins=("$@"); [ ${#plugins[@]} -gt 0 ] || plugins=(warren github coding operator design handoff scaffold)
cfg=$(mktemp -d "${TMPDIR:-/tmp}/warren-projected.XXXXXX"); trap 'rm -rf "$cfg"' EXIT
export CLAUDE_CONFIG_DIR="$cfg"
claude plugin marketplace add "$root" --json >/dev/null
total=0
for p in "${plugins[@]}"; do
  claude plugin install "$p@ai-warren" --scope user --json >/dev/null
  t=$(claude plugin details "$p@ai-warren" | awk '/Always-on:/ {gsub("~", "", $2); print $2}')
  printf '  %-10s ~%s tokens (skill listings)\n' "$p" "$t"
  total=$((total + t))
done
text=$(($(wc -c < "$root/plugins/warren/warren.md"))); hostb=$(($(wc -c < "$host")))
printf '  %-10s ~%s tokens (%s bytes, injected at session start)\n' warren.md $((text / 4)) "$text"
printf '  %-10s ~%s tokens (%s bytes)\n' host $((hostb / 4)) "$hostb"
total=$((total + text / 4 + hostb / 4))
echo "always-loaded rule stack: ~$total tokens"
