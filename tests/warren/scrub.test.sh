#!/usr/bin/env bash
# The pre-push path of the guard: identity check, scrub gate and chaining. Ported from the
# config repo's scrub test, run against the plugin's copy of the hooks in a sandbox HOME.
# Fake secrets, phrases and terms are assembled at run time so this file stays clean, and
# terms from the local lists are never printed.
# The AI-tell list ships with the plugin (git-hooks/scrub/forbidden-text.txt); guard.scrubHubPath,
# when set, points at a throwaway hub clone whose list overrides it.
# The org layer (an org scanner and the local term lists) needs network, access to the org
# scanner and the term lists, so it runs only with SCRUB_TEST_ORG=1, SCRUB_TERMS_DIR naming the
# lists, SCRUB_TEST_ORG_SEGMENT (a remote path segment, e.g. example-org), SCRUB_TEST_ORG_SEGMENT2
# (a second segment run with the extra list) and SCRUB_ORG_SCANNER_URL (the scanner repo). gate.py is copied unchanged, so its org layer is the same.
source "$(dirname "$0")/../assert.sh"
needs_sandbox
TMP=$(mktmp); trap 'rm -rf "$TMP"' EXIT
source "$(dirname "$0")/guard-lib.sh"
TERMS_FROM=${SCRUB_TERMS_DIR:-}
guard_home "$PLUGIN" testperson
export SCRUB_CACHE_DIR="$TMP/cache"
H="$HOME/.config/warren/git-hooks"
g() { git "$@"; }
# mkrepo2 <name> <remote path>: like the source test's mkrepo, remote under $TMP/remotes.
mkrepo2() {
  local r="$TMP/$1" rem="$TMP/remotes/$2"
  mkdir -p "$(dirname "$rem")"; git init -q --bare -b main "$rem"
  git init -q -b main "$r"; echo "demo" > "$r/README"
  g -C "$r" add README && g -C "$r" commit -q -m "chore: init"
  g -C "$r" remote add origin "file://$rem"
  g -C "$r" push -q origin main 2>/dev/null || echo "setup push failed for $1" >&2
}
put() { printf '%b\n' "$3" > "$TMP/$1/$2"; g -C "$TMP/$1" add -- "$2"; g -C "$TMP/$1" commit -q -m "${4:-feat: change}"; }
push() { out=$(g -C "$TMP/$1" push origin "${2:-HEAD}" 2>&1); rc=$?; }
undo() { git -C "$TMP/$1" reset -q --hard "origin/${2:-main}"; }
first_term() { grep -vE '^[[:space:]]*(#|$)' "$SCRUB_TERMS_DIR/$1-terms.txt" | head -1 | tr -d '\r'; }

# A throwaway hub clone whose origin/main holds a one-phrase AI-tell list, for the override.
HUBPHRASE="zz override"" phrase"
mkdir -p "$TMP/hub/governance/claude/hooks"; git init -q -b main "$TMP/hub"
printf '%s\n' "$HUBPHRASE" > "$TMP/hub/governance/claude/hooks/forbidden-text.txt"
git -C "$TMP/hub" add -A && git -C "$TMP/hub" commit -q -m "chore: list"
git -C "$TMP/hub" update-ref refs/remotes/origin/main HEAD
HUB="$TMP/hub"

TOKEN="ghp_$(head -c 36 /dev/zero | tr '\0' 'a')"
KEYHDR="-----BEGIN RSA ""PRIVATE KEY-----"
PHRASE="without further"" ado"
TRAILER="Co-""authored-by: Someone <someone@example.org>"
IP="10.20"".30.40"

echo "## global layer (plain remote)"
mkrepo2 plain plain/demo.git
put plain notes.txt "nothing to see"
push plain; expect 0 "clean push passes"
has "scrub gate: 1 commit(s) clean" "gate reports the clean scan"

put plain cfg.txt "token=$TOKEN"
push plain; expect 1 "GitHub token blocked"
has "cfg.txt:1" "finding names file:line"
has "secret github-token" "finding names the rule"
has "ghp_...(40 chars)" "token shown masked"
hasnt "$TOKEN" "full token never printed"
undo plain

put plain id_rsa "$KEYHDR\nabc"
push plain; expect 1 "private key block blocked"
undo plain

put plain fixture.go "const fake = \"$TOKEN\" // scrub:allow=secret"
push plain; expect 0 "scrub:allow=secret marker allows a known fake"
has "allowed by scrub:allow=secret" "honoured allow is reported"

mkdir -p "$TMP/plain/testdata"; put plain testdata/key.pem "$KEYHDR\nabc"
push plain; expect 1 "key in testdata blocked without a path allow"
git -C "$TMP/plain" config --add guard.scrubAllowPath 'testdata/*'
push plain; expect 0 "guard.scrubAllowPath allows the path"
git -C "$TMP/plain" config --unset-all guard.scrubAllowPath

g -C "$TMP/plain" commit -q --allow-empty -m "feat: x" -m "$TRAILER"
push plain; expect 1 "attribution trailer in a commit message blocked"
has "attribution coauthor-trailer" "trailer finding names the rule"
undo plain

put plain src.txt "$PHRASE"
push plain; expect 0 "AI-tell phrase allowed in a repo without hub governance"
put plain fake-tag.txt "x"; git -C "$TMP/plain" tag -a v9.9.9 -m "release $TOKEN"
push plain v9.9.9; expect 1 "secret in annotated tag message blocked"
git -C "$TMP/plain" tag -d v9.9.9 >/dev/null

echo "## AI-tell list (governed repo), from the plugin by default"
mkrepo2 gov plain/gov.git
mkdir -p "$TMP/gov/.claude/hooks" "$TMP/gov/.github"
cp "$PLUGIN/hooks/forbidden-text.txt" "$TMP/gov/.claude/hooks/forbidden-text.txt"
g -C "$TMP/gov" add .claude && g -C "$TMP/gov" commit -q -m "chore: governance hooks"
push gov; expect 0 "the governance list itself is exempt"
put gov src.txt "$PHRASE"
push gov; expect 1 "AI-tell phrase blocked in a governed repo"
has "src.txt:1" "AI-tell finding names file:line"
has "ai-tell" "AI-tell finding names the rule"
undo gov
put gov CLAUDE.md "$PHRASE"
push gov; expect 0 "CLAUDE.md exempt, as in the hub pre-commit"
put gov README.md "$PHRASE"
push gov; expect 1 "AI-tell in README blocked"
printf '%s\n' "$PHRASE" > "$TMP/gov/.github/docs-allowed-forbidden-text.txt"
g -C "$TMP/gov" add .github && g -C "$TMP/gov" commit -q -m "docs: allow"
push gov; expect 0 "the repo's docs-allowed list allows it in Markdown"
put gov src2.txt "$PHRASE"
push gov; expect 1 "docs allowance does not cover non-docs files"
undo gov
g -C "$TMP/gov" commit -q --allow-empty -m "feat: y" -m "$PHRASE"
push gov; expect 1 "AI-tell in a commit message blocked in a governed repo"
undo gov
[ -s "$PLUGIN/git-hooks/scrub/forbidden-text.txt" ] && ok "the AI-tell list ships with the gate" || bad "the AI-tell list ships with the gate"
cmp -s "$PLUGIN/git-hooks/scrub/forbidden-text.txt" "$PLUGIN/hooks/forbidden-text.txt" \
  && ok "the gate's list matches the command guard's list" || bad "the gate's list matches the command guard's list"
put gov ok.txt "fine"
out=$(g -c guard.scrubHubPath= -C "$TMP/gov" push origin HEAD 2>&1); rc=$?
expect 0 "an empty guard.scrubHubPath falls back to the plugin's list"
undo gov
echo "## guard.scrubHubPath overrides the plugin's list"
put gov src.txt "$PHRASE"
out=$(g -c guard.scrubHubPath="$HUB" -C "$TMP/gov" push origin HEAD 2>&1); rc=$?
expect 0 "with the override, a phrase only the plugin's list has passes"
undo gov
put gov src.txt "$HUBPHRASE"
out=$(g -c guard.scrubHubPath="$HUB" -C "$TMP/gov" push origin HEAD 2>&1); rc=$?
expect 1 "with the override, the hub list's phrase is blocked"
undo gov
put gov ok2.txt "fine"
out=$(g -c guard.scrubHubPath="$TMP/no-such-hub" -C "$TMP/gov" push origin HEAD 2>&1); rc=$?
expect 1 "an override naming a missing hub clone fails closed"
undo gov
put gov ok3.txt "fine"
mv "$H/scrub/forbidden-text.txt" "$TMP/list.bak"
push gov; expect 1 "a missing plugin list fails closed"
mv "$TMP/list.bak" "$H/scrub/forbidden-text.txt"
undo gov

echo "## reviewed allowlist (.github/scrub-allow.txt), AI-tell layer"
ENC=${PHRASE// /%20}
mkdir -p "$TMP/gov/gen" "$TMP/gov/lib"
put gov .github/scrub-allow.txt "# generated code repeats it\nai-tell $ENC gen/*"
push gov; expect 0 "the list itself pushes clean (its phrase is percent-encoded)"
put gov gen/a.go "$PHRASE"
push gov; expect 0 "an ai-tell entry on the remote's default branch allows its path"
has "allowed by .github/scrub-allow.txt@" "the honoured entry is reported"
has "(ai-tell $ENC gen/*)" "the report names the entry"
put gov src3.txt "$PHRASE"
push gov; expect 1 "the same phrase in another path is still blocked"
undo gov
put gov gen/b.go "token=$TOKEN"
push gov; expect 1 "an ai-tell entry never covers a secret"
undo gov
g -C "$TMP/gov" commit -q --allow-empty -m "feat: m" -m "$PHRASE"
push gov; expect 1 "the list is never honoured in a commit message"
undo gov
put gov .github/scrub-allow.txt "# generated code\nai-tell $ENC gen/*\nai-tell $ENC lib/*  # added with the code"
put gov lib/b.go "$PHRASE"
push gov; expect 1 "an entry only in the pushed commits, not the default branch, allows nothing"
undo gov
git clone -q "$TMP/remotes/plain/gov.git" "$TMP/gov2"
put gov2 other.txt "fine"
push gov2; expect 0 "another clone moves the default branch"
put gov gen/c.go "$PHRASE"
push gov; expect 1 "a default branch tip missing from this clone fails closed"
has "git fetch origin" "it says to fetch first"
git -C "$TMP/gov" fetch -q origin; undo gov
put gov gen/c.go "$PHRASE"
push gov; expect 0 "after a fetch the list applies"
put gov .github/scrub-allow.txt "secret AKIA gen/*  # a fake key"
push gov; expect 0 "a list is read only when a finding it could cover turns up"
put gov gen/d.go "$PHRASE"
push gov; expect 1 "a secret entry is refused (fails closed)"
has "secrets can't be allowed" "it says why"
undo gov
put gov .github/scrub-allow.txt "ai-tell $ENC gen/*"
push gov; expect 0 "a list without a reason pushes (nothing to cover)"
put gov gen/d.go "$PHRASE"
push gov; expect 1 "a malformed line fails closed"
has "needs a # reason" "it names the problem"
undo gov
put gov .github/scrub-allow.txt "ai-tell $ENC gen/*  # generated code"
push gov; expect 0 "the list is fixed through a push"

echo "## identity, merges, chaining, deletions"
mkrepo2 idr plain/idr.git
put idr a.txt "token=$TOKEN"
foreign=$(GIT_AUTHOR_NAME=Other GIT_AUTHOR_EMAIL=o@x.y GIT_COMMITTER_NAME=Other GIT_COMMITTER_EMAIL=o@x.y \
  git -C "$TMP/idr" commit-tree "HEAD^{tree}" -p HEAD -m "feat: other")
git -C "$TMP/idr" update-ref refs/heads/main "$foreign"
push idr; expect 1 "wrong author blocked"
has "COMMIT BLOCKED" "identity message shown"
hasnt "scrub gate" "identity check runs first (scrub never reached)"
undo idr

g -C "$TMP/idr" checkout -q -b side; put idr m.txt "side"; g -C "$TMP/idr" checkout -q main; put idr m.txt "main"
g -C "$TMP/idr" merge -q side >/dev/null 2>&1; printf 'resolved %s\n' "$TOKEN" > "$TMP/idr/m.txt"
g -C "$TMP/idr" add m.txt && g -C "$TMP/idr" commit -q --no-edit
push idr; expect 1 "secret added by a merge resolution blocked"
has "m.txt" "merge finding names the file"
undo idr
g -C "$TMP/idr" branch -D side -q
m=$(GIT_COMMITTER_NAME=Other GIT_COMMITTER_EMAIL=o@x.y git -C "$TMP/idr" commit-tree "HEAD^{tree}" -p HEAD -p "$(git -C "$TMP/idr" commit-tree "HEAD^{tree}" -p HEAD -m 'feat: p')" -m "Merge")
git -C "$TMP/idr" update-ref refs/heads/main "$m"
push idr; expect 1 "merge commit with wrong committer blocked"
has "COMMIT BLOCKED" "merge identity message shown"
undo idr

printf '#!/bin/sh\ncat > "%s/chained-stdin"\n' "$TMP" > "$TMP/idr/.git/hooks/pre-push"; chmod +x "$TMP/idr/.git/hooks/pre-push"
put idr c.txt "fine"
push idr main; expect 0 "clean push chains to .git/hooks"
if grep -q "^refs/heads/main [0-9a-f]\{40\} refs/heads/main [0-9a-f]\{40\}$" "$TMP/chained-stdin" 2>/dev/null; then ok "chained hook got intact stdin"; else bad "chained hook got intact stdin"; fi
mkdir -p "$TMP/idr/.husky/_"; printf '#!/bin/sh\ncat > "%s/chainpath-stdin"\n' "$TMP" > "$TMP/idr/.husky/_/pre-push"; chmod +x "$TMP/idr/.husky/_/pre-push"
git -C "$TMP/idr" config guard.chainPath .husky/_
put idr d.txt "fine"
push idr; expect 0 "clean push chains to guard.chainPath"
if [ -s "$TMP/chainpath-stdin" ]; then ok "guard.chainPath hook ran with stdin"; else bad "guard.chainPath hook ran with stdin"; fi
put idr e.txt "token=$TOKEN"; rm -f "$TMP/chainpath-stdin"
push idr; expect 1 "blocked push"
if [ ! -e "$TMP/chainpath-stdin" ]; then ok "blocked push never chains"; else bad "blocked push never chains"; fi
undo idr; git -C "$TMP/idr" config --unset guard.chainPath

g -C "$TMP/idr" checkout -q -b gone; put idr g.txt "token=$TOKEN"
git --git-dir="$TMP/remotes/plain/idr.git" fetch -q "$TMP/idr" gone:gone   # remote side only, no push
g -C "$TMP/idr" checkout -q main
out=$(g -C "$TMP/idr" push origin :gone 2>&1); rc=$?
expect 0 "deletion-only push passes"
hasnt "PUSH BLOCKED" "deletion is not scanned"

SEG=${SCRUB_TEST_ORG_SEGMENT:-}; SEG2=${SCRUB_TEST_ORG_SEGMENT2:-}
if [ "${SCRUB_TEST_ORG:-0}" != 1 ] || [ -z "$TERMS_FROM" ] || [ -z "$SEG" ] || [ -z "$SEG2" ] || [ -z "${SCRUB_ORG_SCANNER_URL:-}" ]; then
  echo "skip: org layer (set SCRUB_TEST_ORG=1, SCRUB_TERMS_DIR, SCRUB_TEST_ORG_SEGMENT, SCRUB_TEST_ORG_SEGMENT2 and SCRUB_ORG_SCANNER_URL to run it)"
  finish; exit 0
fi
export SCRUB_TERMS_DIR="$TERMS_FROM"
TERM_U=$(first_term forbidden | tr '[:lower:]' '[:upper:]')
EXTRA_U=$(first_term extra | tr '[:lower:]' '[:upper:]')
[ -n "$TERM_U" ] && [ -n "$EXTRA_U" ] || { bad "term lists missing in $SCRUB_TERMS_DIR"; finish; }
printf '%s forbidden\n%s forbidden extra\n' "$SEG" "$SEG2" >> "$H/scrub/orgs.conf"
echo "## org layer ($SEG remote)"
mkrepo2 org "$SEG/demo.git"
put org a.txt "plain words"
push org; expect 0 "clean org push passes"
has "org $SEG (scrub.py@" "org scanner ran from origin/main"
if [ -d "$SCRUB_CACHE_DIR/org-scanner.git" ]; then ok "org scanner cached in SCRUB_CACHE_DIR"; else bad "org scanner cached in SCRUB_CACHE_DIR"; fi
if [ ! -e "$H/scrub/cache" ]; then ok "no cache inside the hooks dir"; else bad "no cache inside the hooks dir"; fi
put org net.txt "host = $IP"
push org; expect 1 "private IP blocked"
has "private-ip" "names the private-ip rule"
has "net.txt:1" "names file:line"
hasnt "$IP" "IP shown masked"
undo org
put org h.txt "db01.internal"
push org; expect 1 "internal host name blocked"
undo org
put org e.txt "mail someone@example.invalid"
push org; expect 1 "non-noreply email blocked"
undo org
put org e.txt "1234567+alice@users.noreply.github.com"
push org; expect 0 "noreply email allowed"
put org v.txt "see api.vendorthing.com"
push org; expect 1 "unknown domain blocked"
git -C "$TMP/org" config --add guard.scrubAllowDomain vendorthing.com
push org; expect 0 "guard.scrubAllowDomain allows it"
put org t.txt "by $TERM_U"
push org; expect 1 "forbidden term blocked (case-insensitive)"
has "term (forbidden list)" "names the term list"
hasnt "$TERM_U" "term shown masked"
undo org
printf 'MZ\0\0bin %s\0' "$TERM_U" > "$TMP/org/blob.bin"; g -C "$TMP/org" add blob.bin; g -C "$TMP/org" commit -q -m "feat: bin"
push org; expect 1 "term inside a binary file blocked"
undo org
g -C "$TMP/org" commit -q --allow-empty -m "feat: z"; git -C "$TMP/org" tag -a v0.0.1 -m "for $TERM_U"
push org v0.0.1; expect 1 "term in annotated tag text blocked"
git -C "$TMP/org" tag -d v0.0.1 >/dev/null
out=$(g -C "$TMP/org" push origin "HEAD:refs/heads/x-$TERM_U" 2>&1); rc=$?
expect 1 "term in pushed ref name blocked"
undo org
put org n.txt "host = $IP"; git -C "$TMP/org" update-ref refs/remotes/origin/fake HEAD
push org; expect 1 "org layer judges by ls-remote, not tracking refs"
git -C "$TMP/org" update-ref -d refs/remotes/origin/fake; undo org

echo "## org table: extra list, plan repo, fail closed"
mkrepo2 stw "$SEG2/demo.git"
put stw x.txt "see $EXTRA_U"
push stw; expect 1 "extra term blocked on a second-segment repo"
PLAN=plan; mkrepo2 stwplan "$SEG2/$PLAN.git"
put stwplan x.txt "see $EXTRA_U"
push stwplan; expect 0 "plan repo skips the extra list"
put stwplan y.txt "by $TERM_U"
push stwplan; expect 1 "plan repo still runs the forbidden list"
g -C "$TMP/org" commit -q --allow-empty -m "feat: w"
TC="$TMP/terms-copy"; mkdir -m 700 "$TC"; cp "$SCRUB_TERMS_DIR/extra-terms.txt" "$TC/"
out=$(SCRUB_TERMS_DIR="$TC" g -C "$TMP/org" push origin HEAD 2>&1); rc=$?
expect 1 "missing term list fails closed on an org remote"
has "fails closed" "fail-closed message shown"
has "$TC/forbidden-terms.txt" "names the missing list's path"
out=$(SCRUB_TERMS_DIR="$TMP/no-such-dir" g -C "$TMP/org" push origin HEAD 2>&1); rc=$?
expect 1 "missing term-list dir fails closed on an org remote"
out=$(SCRUB_TERMS_DIR="$TC" g -C "$TMP/plain" push origin HEAD 2>&1); rc=$?
expect 0 "missing org term list does not affect other remotes"
HC="$TMP/hooks-copy"; cp -R "$H" "$HC"
mv "$HC/scrub/gate.py" "$HC/scrub/gate.moved"; put plain z.txt "fine"
git config --global core.hooksPath "$HC"
out=$(git -C "$TMP/plain" push origin HEAD 2>&1); rc=$?
git config --global core.hooksPath "$HOME/.config/git/hooks"
expect 1 "missing gate script fails closed everywhere"

echo "## reviewed allowlist (.github/scrub-allow.txt), org layer"
# scanner_cache <dir> <repo> <rev>: a scanner cache whose origin/main is <rev> of <repo>.
scanner_cache() {
  local src="$1.src.git" sha
  git clone -q --bare "$2" "$src" || return 1
  sha=$(git --git-dir="$src" rev-parse --verify -q "$3^{commit}") || return 1
  git --git-dir="$src" update-ref refs/heads/main "$sha"
  mkdir -p "$1"; git clone -q --bare "$src" "$1/org-scanner.git"
}
OLD_SCANNER=${SCRUB_TEST_OLD_SCANNER:-}   # a scanner revision that predates --allow-file
if [ -n "${SCRUB_TEST_SCANNER:-}" ]; then
  scanner_cache "$TMP/cache-new" "${SCRUB_TEST_SCANNER%@*}" "${SCRUB_TEST_SCANNER##*@}"
else
  scanner_cache "$TMP/cache-new" "$TMP/cache/org-scanner.git" refs/remotes/origin/main
fi || { bad "set up the org scanner for the allowlist cases"; }
[ -z "$OLD_SCANNER" ] || scanner_cache "$TMP/cache-old" "$TMP/cache/org-scanner.git" "$OLD_SCANNER" \
  || bad "set up the old org scanner"
SAVED_CACHE=$SCRUB_CACHE_DIR; export SCRUB_CACHE_DIR="$TMP/cache-new"
VHOST="api.vendor""thing.com"
mkrepo2 orgal "$SEG/allow.git"
mkdir -p "$TMP/orgal/.github" "$TMP/orgal/test" "$TMP/orgal/gen" "$TMP/orgal/h"
put orgal .github/scrub-allow.txt "private-ip $IP test/*  # the test address\n# generated client docs\nfqdn $VHOST gen/*.go"
push orgal; expect 0 "the list's own entries pass on an org remote"
has "allowed by .github/scrub-allow.txt entry itself" "and are reported"
put orgal test/a.txt "host = $IP"
push orgal; expect 0 "a private-ip entry allows its path"
has "allowed by .github/scrub-allow.txt@" "the honoured entry is reported"
has "(private-ip $IP test/*)" "the report names the entry"
put orgal gen/a.go "see $VHOST"
push orgal; expect 0 "an fqdn entry allows its path"
put orgal other.txt "host = $IP"
push orgal; expect 1 "the same value in another path is still blocked"
undo orgal
put orgal gen/b.go "see x.$VHOST"
push orgal; expect 1 "a value is exact: a subdomain isn't covered"
undo orgal
put orgal test/t.txt "by $TERM_U"
push orgal; expect 1 "term-list hits stay unallowable"
undo orgal
put orgal "test/$IP.txt" "x"
push orgal; expect 1 "never honoured in a path"
undo orgal
g -C "$TMP/orgal" commit -q --allow-empty -m "feat: reach $IP"
push orgal; expect 1 "never honoured in a commit message"
undo orgal
out=$(g -C "$TMP/orgal" push origin "HEAD:refs/heads/x-$IP" 2>&1); rc=$?
expect 1 "never honoured in a ref name"
put orgal .github/scrub-allow.txt "private-ip $IP test/*  # the test address\nfqdn $VHOST h/*  # added with the code"
put orgal h/a.txt "see $VHOST"
push orgal; expect 1 "an entry only in the pushed commits, not the default branch, allows nothing"
undo orgal
if [ -n "$OLD_SCANNER" ]; then
put orgal test/b.txt "host = $IP"
out=$(SCRUB_CACHE_DIR="$TMP/cache-old" g -C "$TMP/orgal" push origin HEAD 2>&1); rc=$?
expect 1 "a scanner without the allowlist matcher fails closed"
has "predates --allow-file" "it says why"
undo orgal
fi
export SCRUB_CACHE_DIR=$SAVED_CACHE

finish
