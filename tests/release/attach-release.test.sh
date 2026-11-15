#!/usr/bin/env bash
# scripts/attach-release.sh with a stand-in gh: it uploads into the release that exists for the tag (published before
# draft), replaces a same-named asset on a re-run, and creates only a draft when there is none.
source "$(dirname "$0")/../assert.sh"
command -v jq >/dev/null || { echo "skip: jq is not installed"; exit 0; }
SCRIPT="$ROOT/scripts/attach-release.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
mkdir "$T/bin"
cat > "$T/bin/gh" <<'G'
#!/usr/bin/env bash
# Stand-in gh: logs every call; answers the releases and assets listings from JSON files, running the --jq filter with jq.
echo "gh $*" >> "$FAKE_LOG"
jqf=""; args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do [ "${args[$i]}" = "--jq" ] && jqf="${args[$((i + 1))]}"; done
case "$*" in
  "api repos/o/r/releases --paginate"*) jq -r "$jqf" < "$FAKE_RELEASES" ;;
  "api repos/o/r/releases/"*"/assets --paginate"*) jq -r "$jqf" < "$FAKE_ASSETS" ;;
esac
exit 0
G
chmod +x "$T/bin/gh"
echo x > "$T/a.tar.gz"; echo y > "$T/sums.txt"
export PATH="$T/bin:$PATH" GITHUB_REPOSITORY=o/r FAKE_LOG="$T/log" FAKE_RELEASES="$T/rel.json" FAKE_ASSETS="$T/assets.json"
run() { : > "$FAKE_LOG"; out=$("$SCRIPT" "$@" 2>&1); rc=$?; log=$(cat "$FAKE_LOG"); }

echo '[]' > "$FAKE_ASSETS"
echo '[{"id": 7, "tag_name": "v9.9.9", "draft": true}]' > "$FAKE_RELEASES"
run v1.2.0 "$T/a.tar.gz"
expect 0 "no release for the tag: the script succeeds"
printf '%s' "$log" | grep -qF "release create v1.2.0 --draft --verify-tag --generate-notes" && ok "it creates a draft, never a published release" || bad "it creates a draft"
printf '%s' "$log" | grep -qF "uploads.github.com" && bad "nothing is uploaded when it creates" || ok "creating carries the files itself"

echo '[{"id": 11, "tag_name": "v1.2.0", "draft": false}, {"id": 12, "tag_name": "v1.2.0", "draft": true}, {"id": 13, "tag_name": "v1.1.0", "draft": false}]' > "$FAKE_RELEASES"
run v1.2.0 "$T/a.tar.gz" "$T/sums.txt"
expect 0 "a published and a draft release for the tag: the script succeeds"
printf '%s' "$log" | grep -qF "releases/11/assets?name=a.tar.gz" && ok "it uploads to the published release" || bad "it uploads to the published release"
printf '%s' "$log" | grep -qF "releases/11/assets?name=sums.txt" && ok "every file goes to the same release" || bad "every file goes to the same release"
printf '%s' "$log" | grep -qF "releases/12/" && bad "the draft is left alone" || ok "the draft duplicate is left alone"
printf '%s' "$log" | grep -qF "release create" && bad "no second release is created" || ok "no second release is created"

echo '[{"id": 12, "tag_name": "v1.2.0", "draft": true}]' > "$FAKE_RELEASES"
run v1.2.0 "$T/a.tar.gz"
printf '%s' "$log" | grep -qF "releases/12/assets?name=a.tar.gz" && ok "only a draft exists: it uploads into that draft" || bad "uploads into the draft"

echo '[{"id": 11, "tag_name": "v1.2.0", "draft": false}]' > "$FAKE_RELEASES"
echo '[{"id": 501, "name": "a.tar.gz"}, {"id": 502, "name": "other.txt"}]' > "$FAKE_ASSETS"
run v1.2.0 "$T/a.tar.gz"
printf '%s' "$log" | grep -qF "DELETE repos/o/r/releases/assets/501" && ok "a re-run replaces the same-named asset" || bad "a re-run replaces the asset"
printf '%s' "$log" | grep -qF "assets/502" && bad "other assets stay" || ok "other assets stay"

run
expect 1 "no arguments: usage and a failure"
run v1.2.0 "$T/missing.tar.gz"
expect 1 "a missing file fails before anything is sent"
printf '%s' "$log" | grep -qF "uploads.github.com" && bad "nothing was sent" || ok "nothing was sent"
finish
