#!/usr/bin/env bash
# The rulesets and warren-apply-ruleset / warren-apply-topics, against a stub gh.
source "$(dirname "$0")/lib.sh"
RS="$SC/templates/governance/rulesets"
for f in "$RS"/*.json; do
  got="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(all(k in d for k in ("name","target","enforcement","conditions","rules","bypass_actors")))' "$f" 2>/dev/null)"
  assert_eq "$got" True "${f##*/} is valid JSON with the fields the API needs"
done
tag() {
  python3 -c '
import json, sys
d = json.load(open(sys.argv[1]))
print(d["name"], d["target"], d["conditions"]["ref_name"]["include"], d["conditions"]["repository_name"]["include"],
      [r["type"] for r in d["rules"]], [(a["actor_type"], a["bypass_mode"]) for a in d["bypass_actors"]])' "$RS/$1"
}
assert_eq "$(tag org-v-tags-immutable.json)" "v-tags-immutable tag ['refs/tags/v*'] ['~ALL'] ['update', 'deletion', 'non_fast_forward'] [('OrganizationAdmin', 'always')]" "immutable tag ruleset shape"
assert_eq "$(tag org-v-tags-owner-only.json)" "v-tags-owner-only tag ['refs/tags/v*'] ['~ALL'] ['creation'] [('OrganizationAdmin', 'always')]" "owner-only tag ruleset shape"
assert_eq "$(python3 -c 'import json,sys; print([a["actor_type"] for a in json.load(open(sys.argv[1]))["bypass_actors"]])' "$RS/branch-default.json")" "['RepositoryRole']" "the default ruleset names no particular App"

checks() { python3 -c 'import json,sys; d=json.load(sys.stdin); print([c["context"] for r in d["rules"] if r["type"]=="required_status_checks" for c in r["parameters"]["required_status_checks"]])'; }
actors() { python3 -c 'import json,sys; print([(a["actor_type"], a["actor_id"]) for a in json.load(sys.stdin)["bypass_actors"]])'; }
assert_eq "$(bash "$BIN/warren-apply-ruleset" --print Example-Org/svc --require 'Build & Test' | checks)" "['checks / scrub', 'Build & Test']" "the owner's ruleset, plus a required check"
assert_eq "$(bash "$BIN/warren-apply-ruleset" --print Example-Org/svc | actors)" "[]" "the owner's own ruleset is used as it is"
assert_eq "$(bash "$BIN/warren-apply-ruleset" --print Owner/lib --require X | checks)" "['X']" "the required-checks rule is created on the default"
assert_eq "$(bash "$BIN/warren-apply-ruleset" --print extends-owner/lib | actors)" "[('RepositoryRole', 5), ('Integration', 4242)]" "release-app-id adds the App as a bypass actor"
assert_eq "$(bash "$BIN/warren-apply-ruleset" --print Owner/lib | actors)" "[('RepositoryRole', 5)]" "no App without the setting"

log="$(mktmp)/gh.log"
with_stub_bin gh "printf '%s\n' \"\$*\" >> $log; exit 0"
bash "$BIN/warren-apply-ruleset" --org ExampleOrg "$RS/org-v-tags-immutable.json" >/dev/null
out="$(cat "$log")"
has "-X POST orgs/ExampleOrg/rulesets --input $RS/org-v-tags-immutable.json" "--org posts an org ruleset"
bash "$BIN/warren-apply-ruleset" --org ExampleOrg "$RS/no-such.json" >/dev/null 2>&1; rc=$?
expect 1 "--org fails on a missing file"
: > "$log"; bash "$BIN/warren-apply-ruleset" Owner/lib >/dev/null; out="$(cat "$log")"
has "-X POST repos/Owner/lib/rulesets --input" "a repo ruleset is posted"
has "repo edit Owner/lib --enable-auto-merge --enable-squash-merge" "the merge policy is set"

assert_eq "$(bash "$BIN/warren-apply-topics" --print Owner/x claude-code hook | paste -sd, -)" "claude-code,bash,claude-code-hook" "topics: base plus the variant's"
assert_eq "$(bash "$BIN/warren-apply-topics" --print extends-owner/x go | paste -sd, -)" "golang,example-topic" "topics: the owner's own added"
: > "$log"; bash "$BIN/warren-apply-topics" Owner/x npm >/dev/null; out="$(cat "$log")"
has "repo edit Owner/x --add-topic npm,typescript,nodejs" "topics are added, never replaced"
finish
