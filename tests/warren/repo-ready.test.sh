#!/usr/bin/env bash
# warren-repo-ready reports whether the rules for a repo are there: its GitHub owner's warren plugin
# installed and enabled. The SessionStart hook turns a not-set-up status into advisory context.
# Nothing here makes a commit.
source "$(dirname "$0")/../assert.sh"
tmp=$(mktmp); trap 'rm -rf "$tmp"' EXIT
READY="$PLUGIN/bin/warren-repo-ready"
HOOK="$PLUGIN/hooks/repo-ready.sh"
cfg="$tmp/cfg"; mkdir -p "$cfg/plugins"
export CLAUDE_CONFIG_DIR="$cfg"
export WARREN_EXEMPT="$tmp/exempt"
unset WARREN_ENFORCE

installed() { printf '{"version":2,"plugins":{%s}}\n' "$1" >"$cfg/plugins/installed_plugins.json"; }
user_enabled() { printf '{"enabledPlugins":{%s}}\n' "$1" >"$cfg/settings.json"; }
repo() { mkdir -p "$tmp/$1"; git init -q "$tmp/$1"; [ -z "${2-}" ] || git -C "$tmp/$1" remote add origin "$2"; }
settings() { mkdir -p "$tmp/$1/.claude"; printf '%s\n' "$3" >"$tmp/$1/.claude/$2"; }
status() { "$READY" "$tmp/$1"; }

# The rules come from the repo's GitHub owner's plugin (the marketplace key is the lowercased
# owner), enabled at user level; the repo's own settings are not needed.
installed '"warren@ai-warren":[{"scope":"user"}],"warren-org-acme@acme-corp":[{"scope":"user"}],"warren-org-zed@zed":[{"scope":"user"}]'
user_enabled '"warren@ai-warren":true,"warren-org-acme@acme-corp":true,"warren-org-zed@zed":true'

mkdir -p "$tmp/plain"
out=$(status plain); [ "$out" = "not-a-repo" ] && ok "a folder outside git is not-a-repo" || bad "not-a-repo (got $out)"

repo exempt https://github.com/Acme-Corp/x.git; repo exempt/sub 2>/dev/null; mkdir -p "$tmp/exempt/deep"
out=$(status exempt/deep); [ "$out" = "exempt" ] && ok "a folder under WARREN_EXEMPT is exempt" || bad "exempt (got $out)"

repo bare https://github.com/Acme-Corp/bare.git
out=$(status bare); [ "$out" = "ready" ] && ok "no settings files and the owner's plugin is enabled: ready" || bad "no settings (got $out)"
repo noplugins https://github.com/Acme-Corp/p.git; settings noplugins settings.json '{"model":"x"}'
out=$(status noplugins); [ "$out" = "ready" ] && ok "settings without a plugin list: ready" || bad "no enabledPlugins (got $out)"
repo meta https://github.com/Acme-Corp/m.git; settings meta settings.json '{"enabledPlugins":{"other@elsewhere":true}}'
out=$(status meta); [ "$out" = "ready" ] && ok "a plugin list that names other plugins: ready" || bad "other plugins (got $out)"
mkdir -p "$tmp/bare/src/deep"
out=$(status bare/src/deep); [ "$out" = "ready" ] && ok "a subfolder resolves the top-level repo" || bad "subfolder (got $out)"
out=$(cd "$tmp/bare" && "$READY"); [ "$out" = "ready" ] && ok "the directory defaults to the current one" || bad "default dir (got $out)"

repo ssh git@github.com:Acme-Corp/s.git
out=$(status ssh); [ "$out" = "ready" ] && ok "an scp-style remote gives the owner" || bad "scp remote (got $out)"
repo sshurl ssh://git@github.com/ACME-CORP/s.git
out=$(status sshurl); [ "$out" = "ready" ] && ok "an ssh:// remote gives the owner, case folded" || bad "ssh url (got $out)"

repo other https://github.com/Zed/z.git
out=$(status other); [ "$out" = "ready" ] && ok "another owner finds its own plugin" || bad "other owner (got $out)"
repo nomatch https://github.com/Nobody/n.git
out=$(status nomatch); [ "$out" = "not-set-up:no-org-plugin" ] && ok "the owner's plugin isn't installed: not-set-up" || bad "no org plugin (got $out)"
repo nomatch2 https://github.com/Nobody/n.git; settings nomatch2 settings.json '{"enabledPlugins":{"warren@ai-warren":true}}'
out=$(status nomatch2); [ "$out" = "not-set-up:no-org-plugin" ] && ok "a plugin list in the repo doesn't replace the owner's plugin" || bad "list is not enough (got $out)"

user_enabled '"warren-org-acme@acme-corp":false'
out=$(status bare); [ "$out" = "not-set-up:disabled" ] && ok "installed but not enabled: not-set-up" || bad "disabled (got $out)"
settings bare settings.local.json '{"enabledPlugins":{"warren-org-acme@acme-corp":true}}'
out=$(status bare); [ "$out" = "ready" ] && ok "a repo setting can enable the owner's plugin" || bad "repo enables (got $out)"
rm "$tmp/bare/.claude/settings.local.json"
user_enabled '"warren-org-acme@acme-corp":true'
rm -f "$cfg/settings.json"
out=$(status bare); [ "$out" = "not-set-up:disabled" ] && ok "no enabled flag anywhere: not-set-up" || bad "no flag (got $out)"
user_enabled '"warren-org-acme@acme-corp":true,"warren-org-zed@zed":true'

installed '"warren@ai-warren":[{"scope":"user"}]'
out=$(status bare); [ "$out" = "not-set-up:no-org-plugin" ] && ok "enabled but not installed: not-set-up" || bad "not installed (got $out)"
rm -f "$cfg/plugins/installed_plugins.json"
out=$(status bare); [ "$out" = "not-set-up:no-org-plugin" ] && ok "no installed list at all" || bad "no list (got $out)"
installed '"warren-org-acme@acme-corp":[{"scope":"user"}]'

repo noremote
out=$(status noremote); [ "$out" = "unknown-owner" ] && ok "no remote: the owner is unknown" || bad "no remote (got $out)"
repo gitlab https://gitlab.com/Acme-Corp/g.git
out=$(status gitlab); [ "$out" = "unknown-owner" ] && ok "a remote that isn't github.com: the owner is unknown" || bad "non-github (got $out)"

"$READY" "$tmp/nomatch" >/dev/null; rc=$?; out=""
expect 0 "a status exits 0"

hook() { jq -n --arg d "$tmp/$1" '{cwd:$d}' | "$HOOK"; }
out=$(hook nomatch); rc=$?
expect 0 "the hook exits 0 when not set up"
has "No org plugin for this repo's owner (nobody) is installed: the base warren rules still apply, and the owner's own rules are not loaded. To add them, see /warren:menu." "no org plugin: the hook says the base rules still apply, and names the owner"
hasnt "stop" "and does not tell the session to stop"
has '"additionalContext"' "the hook adds context"
has '"systemMessage"' "the hook adds a system message"
has '"hookEventName": "SessionStart"' "the hook uses the SessionStart shape"
hasnt "Set up this repo" "the hook doesn't send the person to set up the repo"
out=$(WARREN_ENFORCE=off hook nomatch); [ -z "$out" ] && ok "WARREN_ENFORCE=off prints nothing" || bad "enforce off"
out=$(WARREN_ENFORCE=warn hook nomatch); has "No org plugin for this repo's owner" "WARREN_ENFORCE=warn warns"
user_enabled '"warren-org-acme@acme-corp":false'
out=$(hook bare); has "installed but disabled" "an installed but disabled org plugin is a real misconfiguration"
has "Stop and enable it" "and tells the session to stop until it is enabled"
user_enabled '"warren-org-acme@acme-corp":true,"warren-org-zed@zed":true'
out=$(hook bare); [ -z "$out" ] && ok "a ready repo with no plugin list prints nothing" || bad "ready prints"
out=$(hook plain); [ -z "$out" ] && ok "not-a-repo prints nothing" || bad "not-a-repo prints"
out=$(hook exempt/deep); [ -z "$out" ] && ok "an exempt folder prints nothing" || bad "exempt prints"
out=$(hook noremote); [ -z "$out" ] && ok "an unknown owner prints nothing" || bad "unknown owner prints"
finish
