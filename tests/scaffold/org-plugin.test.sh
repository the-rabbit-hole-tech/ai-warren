#!/usr/bin/env bash
# warren-new-org-plugin writes a working org plugin and marketplace for one GitHub owner, and
# warren-repo-ready then counts it as the owner's plugin.
source "$(dirname "$0")/lib.sh"
work="$(mktmp)"; trap 'rm -rf "$work"' EXIT
T="$BIN/warren-new-org-plugin"
rc=0; [ -x "$T" ] || rc=1; out=""; expect 0 "bin/warren-new-org-plugin is executable"

out=$(bash "$T" Acme-Widgets --out "$work/m" --author "Acme Widgets Authors" 2>&1); rc=$?
expect 0 "a run writes the org plugin"
P="$work/m/plugins/warren-org-acme-widgets"
assert_eq "$(present "$work/m/.claude-plugin/marketplace.json")" yes "the marketplace manifest exists"
assert_eq "$(jq -r .name "$work/m/.claude-plugin/marketplace.json")" acme-widgets "the marketplace is named for the lowercased owner"
assert_eq "$(jq -r '.plugins[0].name' "$work/m/.claude-plugin/marketplace.json")" warren-org-acme-widgets "the plugin is warren-org-<owner>"
assert_eq "$(jq -r '.plugins[0].source' "$work/m/.claude-plugin/marketplace.json")" ./plugins/warren-org-acme-widgets "the plugin source points at its folder"
assert_eq "$(jq -r .name "$P/.claude-plugin/plugin.json")" warren-org-acme-widgets "plugin.json names the plugin"
assert_eq "$(jq -r 'has("version")' "$P/.claude-plugin/plugin.json")" false "an org plugin carries no version"
assert_eq "$(present "$P/skills/rules/SKILL.md")" yes "an example rules skill exists"
assert_contains "$(cat "$P/skills/rules/SKILL.md")" "Overrides:" "the example skill shows an Overrides line"
assert_contains "$(cat "$P/scaffold/scaffold.conf")" "owners=Acme-Widgets" "scaffold.conf lists the owner"
assert_contains "$(cat "$P/scaffold/scaffold.conf")" "author=Acme Widgets Authors" "scaffold.conf holds the author"
assert_eq "$(grep -rl '__[A-Z_]*__' "$work/m" | wc -l | tr -d ' ')" 0 "no token is left"
assert_contains "$(cat "$work/m/README.md")" "claude plugin marketplace add" "the README says how to install it"

# warren-repo-ready counts this plugin as the owner's.
cfg="$work/cfg"; mkdir -p "$cfg/plugins" "$work/repo"
git init -q "$work/repo"; git -C "$work/repo" remote add origin https://github.com/Acme-Widgets/x.git
printf '{"plugins":{"warren-org-acme-widgets@acme-widgets":[{"scope":"user"}]}}' > "$cfg/plugins/installed_plugins.json"
printf '{"enabledPlugins":{"warren-org-acme-widgets@acme-widgets":true}}' > "$cfg/settings.json"
assert_eq "$(CLAUDE_CONFIG_DIR="$cfg" bash "$ROOT/plugins/warren/bin/warren-repo-ready" "$work/repo")" ready "the generated name satisfies warren-repo-ready"

out=$(bash "$T" Acme-Widgets --out "$work/m" 2>&1); rc=$?
expect 1 "a run into a non-empty folder is refused"
out=$(bash "$T" "not a name" --out "$work/n" 2>&1); rc=$?
expect 1 "an owner that is not a GitHub name is refused"
out=$(bash "$T" Acme-Widgets 2>&1); rc=$?
expect 1 "--out is required"

if command -v claude >/dev/null 2>&1; then
  cfgv=$(mktmp); out=$(CLAUDE_CONFIG_DIR="$cfgv" claude plugin validate "$P" 2>&1); rc=$?
  expect 0 "the generated plugin validates (no errors; the missing version is deliberate)"
  rm -rf "$cfgv"
fi
finish
