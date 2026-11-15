#!/usr/bin/env bash
# refresh-projects.sh against a fake gh on PATH: no network.
source "$(dirname "$0")/lib.sh"
mkdir -p "$TMP/fakebin" "$TMP/home"
cat > "$TMP/fakebin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
  "repo list") printf 'go-demo\tA demo | module\nnode-thing\tA thing\nhelm-chart\tA chart\n' ;;
  "release list") echo "v1.2.3" ;;
  "api repos/example-org/go-demo/contents/go.mod") printf 'bW9kdWxlIGdpdGh1Yi5jb20vZXhhbXBsZS1vcmcvZ28tZGVtbwo=' ;;
esac
GH
chmod +x "$TMP/fakebin/gh"
export WARREN_CATALOG_ORG=example-org PATH="$TMP/fakebin:$PATH" HOME="$TMP/home" WARREN_CATALOG="$TMP/cat/sub/catalog.md"
out=$("$BIN/refresh-projects.sh" 2>&1); rc=$?
expect 0 "writes the catalog"
has "wrote $TMP/cat/sub/catalog.md" "uses WARREN_CATALOG and creates its folder"
out=$(cat "$WARREN_CATALOG")
has '| `github.com/example-org/go-demo` | v1.2.3 | A demo - module |' "lists the Go module with its version"
has '| `node-thing` | v1.2.3 | A thing |' "lists the npm package"
has '| `example-org/helm-chart` | v1.2.3 | A chart |' "lists the chart"
out=$("$BIN/refresh-projects.sh" "$TMP/explicit.md" 2>&1); rc=$?
assert_true '[ -s "$TMP/explicit.md" ]' "an argument overrides the path"
finish
