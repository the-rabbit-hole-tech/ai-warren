#!/usr/bin/env bash
# The git identity guard: one identity per person per machine, read from the global git config,
# failing closed when it isn't set, and still guarding after a plugin update moves the cache.
source "$(dirname "$0")/../assert.sh"
needs_sandbox
TMP=$(mktmp); trap 'rm -rf "$TMP"' EXIT
source "$(dirname "$0")/guard-lib.sh"

echo "## identity set"
guard_home "$PLUGIN" testperson
mkrepo r
echo a > "$TMP/r/a"; git -C "$TMP/r" add a
out=$(git -C "$TMP/r" commit -q -m "feat: a" 2>&1); rc=$?
expect 0 "a commit as the configured person passes"
echo b > "$TMP/r/b"; git -C "$TMP/r" add b
out=$(GIT_AUTHOR_EMAIL=other@example.org git -C "$TMP/r" commit -q -m "feat: b" 2>&1); rc=$?
expect 1 "a commit with another author email is blocked"
has "COMMIT BLOCKED: AUTHOR email is 'other@example.org'" "the block names the wrong email"
out=$(GIT_COMMITTER_NAME=Other git -C "$TMP/r" commit -q -m "feat: b" 2>&1); rc=$?
expect 1 "a commit with another committer name is blocked"
gh_user someoneelse
out=$(git -C "$TMP/r" commit -q -m "feat: b" 2>&1); rc=$?
expect 1 "a commit while gh is signed in as someone else is blocked"
has "active gh account is 'someoneelse'" "the block names the gh account"
gh_user testperson
out=$(git -C "$TMP/r" push -q origin main 2>&1); rc=$?
expect 0 "a push of the person's own commits passes"
foreign=$(GIT_AUTHOR_NAME=Other GIT_AUTHOR_EMAIL=o@example.org GIT_COMMITTER_NAME=Other GIT_COMMITTER_EMAIL=o@example.org \
  git -C "$TMP/r" commit-tree "HEAD^{tree}" -p HEAD -m "feat: other")
git -C "$TMP/r" update-ref refs/heads/main "$foreign"
out=$(git -C "$TMP/r" push origin main 2>&1); rc=$?
expect 1 "a push carrying another person's commit is blocked"
has "commits not authored and committed as testperson" "the push block names the person"
git -C "$TMP/r" reset -q --hard origin/main

echo "## identity copied from nowhere"
git config --global --unset guard.expectedLogin
out=$(git -C "$TMP/r" commit -q --allow-empty -m "feat: c" 2>&1); rc=$?
expect 1 "with the login unset, a commit is blocked"
has "COMMIT BLOCKED: guard identity not set: run warren init" "the block says how to set it"
out=$(git -C "$TMP/r" push origin main 2>&1); rc=$?
expect 1 "with the login unset, a push is blocked"
git config --global guard.expectedLogin testperson
git config --global --unset hooks.expectedAuthorEmail
out=$(git -C "$TMP/r" commit -q --allow-empty -m "feat: c" 2>&1); rc=$?
expect 1 "with the email unset, a commit is blocked"
git config --global hooks.expectedAuthorEmail 1+testperson@users.noreply.github.com
git -C "$TMP/r" config guard.expectedLogin someoneelse
out=$(git -C "$TMP/r" commit -q --allow-empty -m "feat: c" 2>&1); rc=$?
expect 0 "a repo-local guard setting can't change who may commit"
git -C "$TMP/r" config --unset guard.expectedLogin

echo "## chaining"
printf '#!/bin/sh\necho chained > "%s/chained"\n' "$TMP" > "$TMP/r/.git/hooks/pre-commit"; chmod +x "$TMP/r/.git/hooks/pre-commit"
out=$(git -C "$TMP/r" commit -q --allow-empty -m "feat: d" 2>&1); rc=$?
expect 0 "a clean commit passes"
[ -s "$TMP/chained" ] && ok "the repo's own pre-commit runs after the guard" || bad "the repo's own pre-commit runs after the guard"

echo "## guard sync"
out=$(CLAUDE_PLUGIN_ROOT="$PLUGIN" "$PLUGIN/bin/warren-guard-sync" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "sync reports in sync (exit 0)" || bad "sync reports in sync (exit 0, got $rc)"
cp -R "$PLUGIN" "$TMP/plugin-v2"
printf '\n# v2\n' >> "$TMP/plugin-v2/git-hooks/_dispatch"
out=$(echo '{}' | CLAUDE_PLUGIN_ROOT="$TMP/plugin-v2" "$TMP/plugin-v2/hooks/guard-sync.sh" 2>&1); rc=$?
expect 0 "the SessionStart hook runs after an update"
[ -z "$out" ] && ok "a linked guard gives no session message" || bad "a linked guard gives no session message ($out)"
if tail -1 "$HOME/.config/warren/git-hooks/_dispatch" | grep -q '# v2'; then ok "the stable copy now holds the new version"; else bad "the stable copy now holds the new version"; fi
out=$(CLAUDE_PLUGIN_ROOT="$TMP/plugin-v2" "$TMP/plugin-v2/bin/warren-guard-sync" 2>&1); rc=$?
[ "$rc" = 0 ] && ok "a second sync of the same version changes nothing (exit 0)" || bad "a second sync changes nothing (exit 0, got $rc)"
mv "$TMP/plugin-v2" "$TMP/plugin-v2-gone"
out=$(GIT_AUTHOR_EMAIL=other@example.org git -C "$TMP/r" commit -q --allow-empty -m "feat: e" 2>&1); rc=$?
expect 1 "with the old plugin folder gone, a commit as someone else is still blocked"
printf '\n# v3\n' >> "$TMP/plugin-v2-gone/git-hooks/_dispatch"
out=$(CLAUDE_PLUGIN_ROOT="$TMP/plugin-v2-gone" "$TMP/plugin-v2-gone/bin/warren-guard-sync" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "a changed source re-syncs (exit 3)" || bad "a changed source re-syncs (exit 3, got $rc)"
ln -sfn "$TMP/elsewhere" "$HOME/.config/git/hooks"
out=$(CLAUDE_PLUGIN_ROOT="$PLUGIN" "$PLUGIN/bin/warren-guard-sync" 2>&1); rc=$?
[ "$rc" = 1 ] && ok "a link pointing elsewhere is reported (exit 1)" || bad "a link pointing elsewhere is reported (exit 1, got $rc)"
has "does not link to" "the link problem is named"
out=$(echo '{}' | CLAUDE_PLUGIN_ROOT="$PLUGIN" "$PLUGIN/hooks/guard-sync.sh" 2>&1)
has "systemMessage" "the SessionStart hook tells the session"
[ "$(readlink "$HOME/.config/git/hooks")" = "$TMP/elsewhere" ] && ok "sync never changes the link itself" || bad "sync never changes the link itself"
ln -sfn "$HOME/.config/warren/git-hooks" "$HOME/.config/git/hooks"
git config --global core.hooksPath "$TMP/other-hooks"
out=$(CLAUDE_PLUGIN_ROOT="$PLUGIN" "$PLUGIN/bin/warren-guard-sync" 2>&1); rc=$?
[ "$rc" = 1 ] && ok "a core.hooksPath pointing elsewhere is reported (exit 1)" || bad "a core.hooksPath pointing elsewhere is reported (exit 1, got $rc)"
[ "$(git config --global core.hooksPath)" = "$TMP/other-hooks" ] && ok "sync never changes core.hooksPath" || bad "sync never changes core.hooksPath"

echo "## guard sync never downgrades"
git config --global core.hooksPath "$HOME/.config/git/hooks"
setver() { jq --arg v "$2" '.version=$v' "$1/.claude-plugin/plugin.json" > "$1/pj" && mv "$1/pj" "$1/.claude-plugin/plugin.json"; }
for v in new old newer; do cp -R "$PLUGIN" "$TMP/plugin-$v"; printf '\n# %s\n' "$v" >> "$TMP/plugin-$v/git-hooks/_dispatch"; done
setver "$TMP/plugin-new" 9.0.0; setver "$TMP/plugin-old" 0.9.0; setver "$TMP/plugin-newer" 9.0.1
rm -f "$HOME/.config/warren/git-hooks/PLUGIN_VERSION"
out=$(CLAUDE_PLUGIN_ROOT="$TMP/plugin-new" "$TMP/plugin-new/bin/warren-guard-sync" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "a copy with no recorded version is synced (exit 3)" || bad "a copy with no recorded version is synced (exit 3, got $rc)"
[ "$(cat "$HOME/.config/warren/git-hooks/PLUGIN_VERSION" 2>/dev/null)" = 9.0.0 ] && ok "the sync records the plugin version" || bad "the sync records the plugin version"
synced=$(cat "$HOME/.config/warren/git-hooks/VERSION")
out=$(CLAUDE_PLUGIN_ROOT="$TMP/plugin-old" "$TMP/plugin-old/bin/warren-guard-sync" --quiet 2>&1); rc=$?
[ "$rc" = 4 ] && ok "an older plugin skips the sync (exit 4)" || bad "an older plugin skips the sync (exit 4, got $rc)"
has "0.9.0 is older than the installed 9.0.0" "the skip names both versions, even with --quiet"
[ "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" = 1 ] && ok "the skip notice is one line" || bad "the skip notice is one line ($out)"
[ "$(cat "$HOME/.config/warren/git-hooks/VERSION")" = "$synced" ] && ok "the older plugin leaves the hash alone" || bad "the older plugin leaves the hash alone"
tail -1 "$HOME/.config/warren/git-hooks/_dispatch" | grep -q '# new' && ok "the older plugin leaves the guard alone" || bad "the older plugin leaves the guard alone"
[ "$(cat "$HOME/.config/warren/git-hooks/PLUGIN_VERSION")" = 9.0.0 ] && ok "the older plugin leaves the recorded version alone" || bad "the older plugin leaves the recorded version alone"
out=$(echo '{}' | CLAUDE_PLUGIN_ROOT="$TMP/plugin-old" "$TMP/plugin-old/hooks/guard-sync.sh" 2>&1); rc=$?
expect 0 "the SessionStart hook still exits 0 on a skip"
has "is older than the installed" "the SessionStart hook tells the session about the skip"
setver "$TMP/plugin-old" ""
out=$(CLAUDE_PLUGIN_ROOT="$TMP/plugin-old" "$TMP/plugin-old/bin/warren-guard-sync" --quiet 2>&1); rc=$?
[ "$rc" = 4 ] && ok "a plugin with no readable version never overwrites a recorded one (exit 4)" || bad "a plugin with no readable version never overwrites a recorded one (exit 4, got $rc)"
out=$(CLAUDE_PLUGIN_ROOT="$TMP/plugin-newer" "$TMP/plugin-newer/bin/warren-guard-sync" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "a newer plugin syncs (exit 3)" || bad "a newer plugin syncs (exit 3, got $rc)"
[ "$(cat "$HOME/.config/warren/git-hooks/PLUGIN_VERSION")" = 9.0.1 ] && ok "the newer version is recorded" || bad "the newer version is recorded"
printf '\n# newer-edit\n' >> "$TMP/plugin-newer/git-hooks/_dispatch"
out=$(CLAUDE_PLUGIN_ROOT="$TMP/plugin-newer" "$TMP/plugin-newer/bin/warren-guard-sync" 2>&1); rc=$?
[ "$rc" = 3 ] && ok "the same version with changed content still syncs (exit 3)" || bad "the same version with changed content still syncs (exit 3, got $rc)"
finish
