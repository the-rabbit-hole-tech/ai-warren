#!/usr/bin/env bash
# Runs every tests/**/*.test.sh and fails if any of them fails.
#   bash tests/run.sh [pattern]
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
failed=()
while IFS= read -r t; do
  echo "== $t"
  if ! bash "$t"; then failed+=("$t"); fi
done < <(find tests -name '*.test.sh' | LC_ALL=C sort | grep -e "${1:-.}")
if [ "${#failed[@]}" -gt 0 ]; then
  printf 'FAILED: %s\n' "${failed[@]}"; exit 1
fi
echo "all test files passed"
