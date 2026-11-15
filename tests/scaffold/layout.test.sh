#!/usr/bin/env bash
# The managed "Project layout" block: the ecosystem/variant matrix, rendering, stripping and the
# overlay's refresh. Ported from the governance template's layout test.
source "$(dirname "$0")/lib.sh"
scaffold_lib
work="$(mktmp)"; trap 'rm -rf "$work"' EXIT

MATRIX="go:lib,cli,app npm:lib,cli,app fastify:plugin,app vite:app storybook:library
action:action python:lib,cli,app rust:cli,app claude-code:hook,statusline swift:app,package"
for entry in $MATRIX; do
  eco="${entry%%:*}"; variants="${entry#*:}"
  assert_eq "$(layout_default "$eco")" "${variants%%,*}" "$eco default is ${variants%%,*}"
  for v in ${variants//,/ }; do
    f="$ECOS/$eco/layouts/$v.md"
    assert_eq "$(present "$f")" yes "$eco/$v layout exists"
    [ -f "$f" ] || continue
    body="$(cat "$f")"
    assert_contains "$body" '```text' "$eco/$v has a directory tree"
    assert_contains "$body" "### What goes where" "$eco/$v says what goes where"
    assert_contains "$body" "### Naming" "$eco/$v has naming conventions"
    assert_contains "$body" "### Tests, fixtures and generated code" "$eco/$v places tests, fixtures and generated code"
  done
done
leaks="$(grep -rniE 'github\.com/|[a-z0-9-]+\.(com|org|net|io|dev)([/:]|$|[[:space:]])' "$ECOS"/*/layouts/ || true)"
assert_eq "$leaks" "" "layouts carry only generic names"
layout_file go nope >/dev/null 2>&1; rc=$?; expect 1 "an unknown variant is rejected"

printf '# Repo\n\nOwn intro.\n\n<!-- layout:begin go/app -->\nstale\n<!-- layout:end -->\n\n## Own section\n\nKeep me.\n' > "$work/c.md"
layout_render "$work/c.md" go app
out="$(cat "$work/c.md")"
assert_contains "$out" "<!-- layout:begin go/app -->" "render keeps the spec in the begin marker"
assert_contains "$out" "$(cat "$ECOS/go/layouts/app.md")" "render inserts the layout body"
assert_contains "$out" 'The `go/app` baseline layout.' "render names the layout and no template path"
assert_eq "$(grep -c '^stale$' "$work/c.md")" 0 "render drops the stale block"
assert_eq "$(head -4 "$work/c.md")" "$(printf '# Repo\n\nOwn intro.\n')" "content before the block untouched"
assert_eq "$(tail -4 "$work/c.md")" "$(printf '\n## Own section\n\nKeep me.')" "content after the block untouched"
cp "$work/c.md" "$work/once.md"; layout_render "$work/c.md" go app
assert_eq "$(cat "$work/c.md")" "$(cat "$work/once.md")" "render is idempotent"
assert_eq "$(layout_spec "$work/c.md")" go/app "spec read back from the marker"
printf '```\n<!-- layout:begin go/cli -->\n```\n' > "$work/fence.md"
assert_eq "$(layout_spec "$work/fence.md")" "" "a marker in a code fence is an example"
printf '<!-- layout:begin Go Lib -->\n' > "$work/badm.md"
layout_spec "$work/badm.md" >/dev/null 2>&1; rc=$?; expect 1 "a malformed marker fails"

printf 'a\n\n<!-- layout:begin -->\n<!-- layout:end -->\n\nb\n' > "$work/s.md"
layout_strip "$work/s.md"
assert_eq "$(cat "$work/s.md")" "$(printf 'a\n\nb')" "strip removes only the block"

compose go "$work/go-default" public "" "" >/dev/null
assert_eq "$(layout_spec "$work/go-default/CLAUDE.md")" go/lib "compose without a variant uses the default"
compose npm "$work/npm-cli" public cli "" >/dev/null
assert_eq "$(layout_spec "$work/npm-cli/CLAUDE.md")" npm/cli "compose renders the chosen variant"

ov() { ( org_use Owner; org_env Owner repo "A repo."; apply_overlay ) >/dev/null 2>&1; }
r="$(mktmp)"; cd "$r" || exit 1
printf '# CLAUDE.md\n\n<!-- layout:begin python/cli -->\nold layout\n<!-- layout:end -->\n' > CLAUDE.md
ov; rc=$?; expect 0 "overlay over a recorded layout"
assert_eq "$(layout_spec CLAUDE.md)" python/cli "overlay keeps the recorded variant"
assert_contains "$(cat CLAUDE.md)" "$(cat "$ECOS/python/layouts/cli.md")" "overlay refreshes the block"
assert_eq "$(grep -c '^old layout$' CLAUDE.md)" 0 "overlay drops the stale layout"
r="$(mktmp)"; cd "$r" || exit 1
printf '<!-- layout:begin fastify -->\n<!-- layout:end -->\n' > CLAUDE.md
ov; assert_eq "$(layout_spec CLAUDE.md)" fastify/plugin "an ecosystem-only marker gets the default variant"
r="$(mktmp)"; cd "$r" || exit 1
ov; assert_eq "$(grep -c 'layout:' CLAUDE.md)" 0 "no recorded layout -> no block"
r="$(mktmp)"; cd "$r" || exit 1
printf '<!-- layout:begin go/nope -->\n<!-- layout:end -->\n' > CLAUDE.md
ov; rc=$?; expect 1 "overlay rejects an unknown recorded layout"

cd "$work" || exit 1
out="$(bash "$BIN/warren-new-repo" demo go --variant nope --org Owner --dry-run -d x 2>&1)"; rc=$?
assert_eq "$rc" 2 "new-repo rejects an unknown variant"
has "lib cli app" "new-repo lists the valid variants"
assert_eq "$(present "$work/demo")" no "nothing scaffolded for a bad variant"
bash "$BIN/warren-new-repo" demo go --variant app --org Owner --dry-run -d "A demo." >/dev/null 2>&1
assert_eq "$(layout_spec "$work/demo/CLAUDE.md" 2>/dev/null)" go/app "new-repo writes the chosen variant"
finish
