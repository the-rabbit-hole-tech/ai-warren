#!/usr/bin/env bash
# backlog-page.py needs the hand-off site's _site/ (page.py, pagefile.py, schema.py), which lives
# in this repo (adapters/handoff-web).
source "$(dirname "$0")/lib.sh"
# The hand-off web lives in this repo (adapters/handoff-web), so the test runs against it unless HANDOFF_SITE_SRC names another
# site. The machine's live site (WARREN_HANDOFF_SITE) is not used: the test must run against the code in this checkout.
src="${HANDOFF_SITE_SRC:-$ROOT/adapters/handoff-web/template}"
if [ -z "$src" ] || [ ! -f "$src/_site/page.py" ]; then
  echo "skip backlog-page.test.sh: no hand-off site _site/ (set HANDOFF_SITE_SRC)"
  exit 0
fi
export HANDOFF_SITE_SRC="$src" BACKLOG_PAGE="$BIN/backlog-page.py"
python3 -I "$(dirname "$0")/backlog_page_test.py" >"$TMP/out" 2>&1; rc=$?
out=$(cat "$TMP/out"); expect 0 "backlog-page unit tests pass"
finish
