#!/usr/bin/env bash
# Shared code for the scaffold plugin's bin/ scripts: the ecosystem layouts, the owner's scaffold
# settings, composing a new repo's tree, filling its tokens and laying the shared governance into
# an existing repo. Source it after setting SCAFFOLD_ROOT to the plugin folder.
#
# The plugin holds only generic templates. Everything that belongs to one owner (copyright holder,
# licence, operator, CODEOWNERS, ruleset, files the owner's .github repo already provides, starting
# files) lives in that owner's org or personal plugin, in a scaffold/ folder:
#
#   scaffold/scaffold.conf      key=value settings (see README.md for every key)
#   scaffold/CODEOWNERS         replaces the CODEOWNERS baseline (compose), or adds its missing
#                               lines to a repo's own file (apply)
#   scaffold/ruleset.json       the owner's branch ruleset (warren-apply-ruleset)
#   scaffold/governance.skip    shared files the owner doesn't take, one repo-relative path a line
#   scaffold/labels.yml         replaces the canonical label set
#   scaffold/topics             topics every new repo of the owner gets, one a line
#   scaffold/overlay/           files a new repo starts with (licence, NOTICE, a required CI caller)
#   scaffold/protected          repos the shared governance never touches, one name a line
#   scaffold/repo-skip          `<repo> <path>` lines: a shared file one repo keeps out
#
# The folder is found by owner: the first scaffold.conf whose `owners=` names the GitHub owner,
# searched in --scaffold-dir, then $WARREN_SCAFFOLD_DIRS (colon-separated), then the scaffold/
# folders of the plugins in the installed marketplaces. An owner without one gets the generic
# defaults. Portable to bash 3.2 (macOS); no network.

: "${SCAFFOLD_ROOT:?set SCAFFOLD_ROOT to the scaffold plugin folder}"
TPL="$SCAFFOLD_ROOT/templates"
GOV="$TPL/governance"
ECOS="$TPL/ecosystems"
ORG_DIR="${ORG_DIR:-}"

LAYOUT_BEGIN_RE='^<!-- layout:begin( [^ ]*)? -->$'
LAYOUT_END='<!-- layout:end -->'

# --- ecosystems and layouts ---------------------------------------------------------------------

# eco_list: the ecosystems that have a template, on one line.
eco_list() {
  (cd "$ECOS" && for d in */template; do printf '%s ' "${d%/template}"; done) | sed 's/ $//'
}

# layout_variants <eco>: the ecosystem's variants on one line, default first.
layout_variants() {
  local f="$ECOS/$1/layouts/variants"
  [ -f "$f" ] || return 1
  grep -vE '^[[:space:]]*(#|$)' "$f" | tr '\n' ' ' | sed 's/ $//'
}

# layout_default <eco>: the default variant.
layout_default() {
  local all
  all="$(layout_variants "$1")" || return 1
  [ -n "$all" ] || return 1
  printf '%s\n' "${all%% *}"
}

# layout_file <eco> <variant>: the layout path, or fail with the valid variants on stderr.
layout_file() {
  local eco="$1" v="$2" f
  f="$ECOS/$eco/layouts/$v.md"
  case "$v" in *[!a-z0-9-]*|'') f="" ;; esac
  if [ -z "$f" ] || [ ! -f "$f" ]; then
    echo "unknown layout $eco/$v (variants: $(layout_variants "$eco" || echo none))" >&2
    return 1
  fi
  printf '%s\n' "$f"
}

# layout_spec <file>: the <eco>[/<variant>] in the begin marker of a CLAUDE.md, or nothing when
# there is none. A marker that is there but unusable fails with the line on stderr. Markers inside
# fenced code blocks are examples and are skipped.
layout_spec() {
  [ -f "$1" ] || return 0
  awk -v file="$1" '
    function fail(msg) { printf "%s:%d: %s: %s\n", file, NR, msg, $0 > "/dev/stderr"; bad = 1; exit }
    { sub(/\r$/, "") }
    fence != "" {
      if ($0 ~ /^ ? ? ?(`+|~+)[ \t]*$/) {
        f = $0; gsub(/[ \t]/, "", f)
        if (substr(f, 1, 1) == substr(fence, 1, 1) && length(f) >= length(fence)) fence = ""
      }
      next
    }
    match($0, /^ ? ? ?(```+|~~~+)/) { fence = substr($0, RSTART, RLENGTH); gsub(/ /, "", fence); next }
    /^[ \t]*<!--/ && index($0, "layout:begin") {
      if ($0 !~ /^[ \t]*<!--[ \t]*layout:begin([ \t]+[^ \t]+)?[ \t]*-->[ \t]*$/) fail("malformed layout marker")
      if (found) fail("duplicate layout marker (the first is on line " first ")")
      s = $0
      sub(/^[ \t]*<!--[ \t]*layout:begin[ \t]*/, "", s)
      sub(/[ \t]*-->[ \t]*$/, "", s)
      if (s == "") fail("layout marker names no layout (want <eco>/<variant>)")
      if (s !~ /^[a-z0-9-]+(\/[a-z0-9-]+)?$/) fail("bad layout \"" s "\" (want <eco>/<variant> in a-z, 0-9 and -)")
      found = 1; first = NR; spec = s
    }
    END { if (bad) exit 1; if (found) print spec }
  ' "$1"
}

# layout_render <file> <eco> [variant]: replace the marked block with the rendered layout.
# Everything outside the markers is left byte for byte.
layout_render() {
  local file="$1" eco="$2" v="${3:-}" src block
  [ -n "$v" ] || v="$(layout_default "$eco")" || { echo "no layouts for ecosystem: $eco" >&2; return 1; }
  src="$(layout_file "$eco" "$v")" || return 1
  grep -qE "$LAYOUT_BEGIN_RE" "$file" || { echo "$file: no layout marker" >&2; return 1; }
  block="$(mktemp)"
  {
    printf '<!-- layout:begin %s/%s -->\n' "$eco" "$v"
    printf '## Project layout\n\n'
    # shellcheck disable=SC2016 # literal backticks: Markdown code spans
    printf 'The `%s/%s` baseline layout.\n' "$eco" "$v"
    printf 'This block is rendered again from the begin marker whenever the shared governance is\n'
    printf 'applied, so keep repo-specific notes in AGENTS.md, which is left alone.\n\n'
    cat "$src"
    printf '%s\n' "$LAYOUT_END"
  } > "$block"
  awk -v block="$block" -v end="$LAYOUT_END" -v begin="$LAYOUT_BEGIN_RE" '
    skipping { if ($0 == end) skipping = 0; next }
    !done && $0 ~ begin {
      while ((getline line < block) > 0) print line
      close(block); skipping = 1; done = 1; next
    }
    { print }
  ' "$file" > "$file.layout.tmp" && mv "$file.layout.tmp" "$file"
  rm -f "$block"
}

# layout_strip <file>: remove the marked block and the blank line after it.
layout_strip() {
  local file="$1"
  awk -v end="$LAYOUT_END" -v begin="$LAYOUT_BEGIN_RE" '
    skipping { if ($0 == end) { skipping = 0; eat = 1 } ; next }
    $0 ~ begin { skipping = 1; next }
    eat && $0 == "" { eat = 0; next }
    { eat = 0; print }
  ' "$file" > "$file.layout.tmp" && mv "$file.layout.tmp" "$file"
}

# eco_governance <eco> <dir>: the ecosystem's own governance. workflows.skip names shared
# workflows the ecosystem can't run; sync.overlay/ holds files every repo of it carries.
eco_governance() {
  local src="$ECOS/$1" dir="$2" wf
  if [ -f "$src/workflows.skip" ]; then
    while IFS= read -r wf || [ -n "$wf" ]; do
      case "$wf" in ''|'#'*|*/*|.*) continue ;; esac
      rm -f "$dir/.github/workflows/$wf"
    done < "$src/workflows.skip"
  fi
  if [ -d "$src/sync.overlay" ]; then
    cp -R "$src/sync.overlay/." "$dir/"
  fi
}

# --- the owner's scaffold settings --------------------------------------------------------------

# scaffold_candidates: every scaffold folder to look in, one a line, in search order.
scaffold_candidates() {
  local d cfg old_ifs
  [ -z "${SCAFFOLD_DIR_FLAG:-}" ] || printf '%s\n' "$SCAFFOLD_DIR_FLAG"
  if [ -n "${WARREN_SCAFFOLD_DIRS:-}" ]; then
    old_ifs=$IFS; IFS=:
    for d in $WARREN_SCAFFOLD_DIRS; do [ -n "$d" ] && printf '%s\n' "$d"; done
    IFS=$old_ifs
  fi
  [ "${WARREN_SCAFFOLD_SEARCH:-1}" = 0 ] && return 0
  cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  for d in "$cfg"/plugins/marketplaces/*/plugins/*/scaffold; do
    [ -f "$d/scaffold.conf" ] && printf '%s\n' "$d"
  done
  return 0
}

# conf_get <conf file> <key>: the value, or nothing.
conf_get() {
  [ -f "$1" ] || return 0
  sed -n "s/^$2=//p" "$1" | head -1
}

# scaffold_find <owner>: the scaffold folder whose scaffold.conf names the owner, or nothing.
# --scaffold-dir is taken as given even when its owners= doesn't list the owner.
scaffold_find() {
  local owner d o lc_owner
  owner="$1"; [ -n "$owner" ] || return 0
  lc_owner="$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')"
  if [ -n "${SCAFFOLD_DIR_FLAG:-}" ]; then
    [ -f "$SCAFFOLD_DIR_FLAG/scaffold.conf" ] || { echo "no scaffold.conf in $SCAFFOLD_DIR_FLAG" >&2; return 1; }
    (cd "$SCAFFOLD_DIR_FLAG" && pwd)
    return 0
  fi
  while IFS= read -r d; do
    for o in $(conf_get "$d/scaffold.conf" owners | tr ',' ' '); do
      if [ "$(printf '%s' "$o" | tr '[:upper:]' '[:lower:]')" = "$lc_owner" ]; then
        (cd "$d" && pwd); return 0
      fi
    done
  done < <(scaffold_candidates)
  return 0
}

# org_use <owner>: set ORG_DIR for the owner (empty for an owner with no settings).
org_use() {
  ORG_DIR="$(scaffold_find "$1")" || return 1
  return 0
}

# org_setting <key> [default]: the owner's setting, or the default.
org_setting() {
  local v=""
  [ -z "$ORG_DIR" ] || v="$(conf_get "$ORG_DIR/scaffold.conf" "$1")"
  printf '%s\n' "${v:-${2:-}}"
}

# skip_path <dir> <path> <source>: remove one repo-relative path; paths that climb out are ignored.
skip_path() {
  case "/$2/" in
    //*|*/../*|*/./*) echo "skip: ignoring unsafe path '$2' in $3" >&2; return 0 ;;
  esac
  rm -rf "${1:?}/$2"
}

# org_skip <dir> [repo]: remove the shared files the owner doesn't take (governance.skip), and
# the ones this repo keeps out (repo-skip lines naming it).
org_skip() {
  local dir="$1" repo="${2:-}" f p r
  [ -n "$ORG_DIR" ] || return 0
  f="$ORG_DIR/governance.skip"
  if [ -f "$f" ]; then
    while IFS= read -r p || [ -n "$p" ]; do
      case "$p" in ''|'#'*) continue ;; esac
      skip_path "$dir" "$p" "$f"
    done < "$f"
  fi
  f="$ORG_DIR/repo-skip"
  if [ -n "$repo" ] && [ -f "$f" ]; then
    while read -r r p _ || [ -n "$r" ]; do
      case "$r" in ''|'#'*) continue ;; esac
      [ "$r" = "$repo" ] && [ -n "$p" ] && skip_path "$dir" "$p" "$f"
    done < "$f"
  fi
  return 0
}

# org_protected <repo>: 0 when the owner lists the repo as protected.
org_protected() {
  local f="$ORG_DIR/protected" r
  [ -n "$ORG_DIR" ] && [ -f "$f" ] || return 1
  while read -r r _ || [ -n "$r" ]; do
    case "$r" in ''|'#'*) continue ;; esac
    [ "$r" = "$1" ] && return 0
  done < "$f"
  return 1
}

# org_codeowners <dir>: 0 when the owner has a CODEOWNERS baseline (laid down, or its missing
# lines appended), 1 when it has none.
org_codeowners() {
  local src="$ORG_DIR/CODEOWNERS" dst="$1/.github/CODEOWNERS" line
  [ -n "$ORG_DIR" ] && [ -f "$src" ] || return 1
  mkdir -p "$1/.github"
  if [ ! -f "$dst" ]; then cp "$src" "$dst"; return 0; fi
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    grep -qxF -- "$line" "$dst" || printf '%s\n' "$line" >> "$dst"
  done < "$src"
  return 0
}

# org_labels: the label set to lay down.
org_labels() {
  if [ -n "$ORG_DIR" ] && [ -f "$ORG_DIR/labels.yml" ]; then echo "$ORG_DIR/labels.yml"
  else echo "$GOV/.github/labels.yml"; fi
}

# org_overlay <dir>: lay the owner's starting files over a new tree.
org_overlay() {
  [ -n "$ORG_DIR" ] && [ -d "$ORG_DIR/overlay" ] || return 0
  cp -R "$ORG_DIR/overlay/." "$1/"
}

# org_ruleset: the owner's ruleset file, or nothing.
org_ruleset() {
  [ -n "$ORG_DIR" ] && [ -f "$ORG_DIR/ruleset.json" ] && printf '%s\n' "$ORG_DIR/ruleset.json"
  return 0
}

# org_topics: the owner's own topics, one a line.
org_topics() {
  [ -n "$ORG_DIR" ] && [ -f "$ORG_DIR/topics" ] || return 0
  grep -vE '^[[:space:]]*(#|$)' "$ORG_DIR/topics"
}

# org_funding <dir>: write .github/FUNDING.yml when the owner names a sponsor account.
org_funding() {
  local who; who="$(org_setting funding)"
  [ -n "$who" ] || return 0
  mkdir -p "$1/.github"
  printf 'github: [%s]\n' "$who" > "$1/.github/FUNDING.yml"
}

# org_license_text <dir>: put the owner's licence text in a new tree. The base ships Apache-2.0 and
# MIT (templates/licenses/<SPDX>.txt); any other licence needs the owner's overlay/LICENSE, which
# the overlay lays down after this. The text carries __YEAR__ and __AUTHOR__ for fill_tree.
org_license_text() {
  local lic txt
  lic="$(org_setting license Apache-2.0)"
  txt="$SCAFFOLD_ROOT/templates/licenses/$lic.txt"
  if [ -f "$txt" ]; then cp "$txt" "$1/LICENSE"; return 0; fi
  [ -n "$ORG_DIR" ] && [ -f "$ORG_DIR/overlay/LICENSE" ] && return 0
  echo "no licence text for $lic: add overlay/LICENSE to the owner's scaffold/ folder, or use Apache-2.0 or MIT" >&2
  return 1
}

# default_golic <spdx>: the golic template key for a licence the base knows.
default_golic() { case "$1" in MIT) echo mit ;; *) echo apache2 ;; esac; }

# org_env <owner> <repo> [description]: export the token values for the owner and repo.
org_env() {
  OWNER="$1"; REPO_NAME="$2"; DESCRIPTION="${3:-${DESCRIPTION:-A new project.}}"
  YEAR="${YEAR:-$(date +%Y)}"
  AUTHOR="${AUTHOR:-$(org_setting author)}"
  if [ -z "$AUTHOR" ]; then
    echo "note: no copyright holder set (author= in the owner's scaffold.conf); using $OWNER" >&2
    AUTHOR="$OWNER"
  fi
  LICENSE="$(org_setting license Apache-2.0)"
  GOLIC_LICENSE="$(org_setting golic-license "$(default_golic "$LICENSE")")"
  OPERATOR="$(org_setting operator "$OWNER")"
  NOTES_DIR="$(org_setting notes-dir plan/)"
  RELEASE_DRAFTER_EXTENDS="$(org_setting release-drafter-extends)"
  PKG="${PKG:-$(printf '%s' "$REPO_NAME" | sed -E 's/^(lib|ms|ui|app|go|svc)-//; s/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')}"
  [ -n "$PKG" ] || PKG="$(printf '%s' "$REPO_NAME" | sed -E 's/[^a-zA-Z0-9]//g' | tr '[:upper:]' '[:lower:]')"
  SCRIPT_NAME="$REPO_NAME"
  PYPKG="${PYPKG:-$(printf '%s' "$REPO_NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/^_+//; s/_+$//')}"
  export OWNER REPO_NAME DESCRIPTION YEAR AUTHOR LICENSE GOLIC_LICENSE OPERATOR NOTES_DIR \
    RELEASE_DRAFTER_EXTENDS PKG PYPKG SCRIPT_NAME
}

# script_name <dir>: the claude-code add-on script name from the layout marker. A user has one
# status line, so it is statusline.sh; hooks share one folder, so each is hook-<name>.sh.
script_name() {
  case "$(sed -n 's|^<!-- layout:begin claude-code/\([a-z0-9-]*\) -->$|\1|p' "$1/CLAUDE.md" 2>/dev/null | head -1)" in
    statusline) echo statusline ;;
    hook) echo "hook-${REPO_NAME#claude-code-hook-}" ;;
    *) echo "$REPO_NAME" ;;
  esac
}

# fill_file <file>...: fill the tokens in place, literally (values never act as regex).
fill_file() {
  perl -i -pe '
    s/__OWNER__/$ENV{OWNER}/g;
    s/__REPO_NAME__/$ENV{REPO_NAME}/g;
    s/__DESCRIPTION__/$ENV{DESCRIPTION}/g;
    s/__AUTHOR__/$ENV{AUTHOR}/g;
    s/__YEAR__/$ENV{YEAR}/g;
    s/__PKG__/$ENV{PKG}/g;
    s/__PYPKG__/$ENV{PYPKG}/g;
    s/__SCRIPT_NAME__/$ENV{SCRIPT_NAME}/g;
    s/__LICENSE__/$ENV{LICENSE}/g;
    s/__GOLIC_LICENSE__/$ENV{GOLIC_LICENSE}/g;
    s/__OPERATOR__/$ENV{OPERATOR}/g;
    s/__NOTES_DIR__/$ENV{NOTES_DIR}/g;
    s/__RELEASE_DRAFTER_EXTENDS__/$ENV{RELEASE_DRAFTER_EXTENDS}/g;
  ' "$@"
}

# fill_tree <dir>: fill every text file's tokens, rename token paths, set the notes folder in
# .gitignore and strip README emoji for an owner with readme-emoji=false. Needs org_env first.
fill_tree() {
  local dir="$1" p np
  SCRIPT_NAME="$(script_name "$dir")"; export SCRIPT_NAME
  while IFS= read -r -d '' p; do
    case "$p" in
      *.png|*.jpg|*.jpeg|*.gif|*.pdf|*.ico|*.woff|*.woff2|*.ttf|*.zip|*.gz|*.dotx|*.potx|*.pptx) continue ;;
    esac
    fill_file "$p"
  done < <(find "$dir" -path "$dir/.git" -prune -o -type f -print0)
  find "$dir" -depth -name '*__*' -not -path "$dir/.git/*" | while IFS= read -r p; do
    np="$(printf '%s' "$p" | sed -e "s/__OWNER__/$OWNER/g" -e "s/__REPO_NAME__/$REPO_NAME/g" \
          -e "s/__PKG__/$PKG/g" -e "s/__PYPKG__/$PYPKG/g" -e "s/__SCRIPT_NAME__/$SCRIPT_NAME/g")"
    if [ "$p" != "$np" ]; then mkdir -p "$(dirname "$np")"; mv "$p" "$np"; fi
  done
  if [ "$NOTES_DIR" != plan/ ] && [ -f "$dir/.gitignore" ]; then
    perl -pi -e 's{^plan/$}{$ENV{NOTES_DIR}}' "$dir/.gitignore"
  fi
  if [ "$(org_setting readme-emoji true)" = false ] && [ -f "$dir/README.md" ]; then
    perl -CSD -i -pe 's/ ?[\x{1F000}-\x{1FAFF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}]\x{FE0F}?(?= |$)//g' "$dir/README.md"
  fi
}

# --- compose a new repo -------------------------------------------------------------------------

# compose <eco> <out> <public|private> <variant> <owner>: lay the ecosystem template, the shared
# governance and the owner's files into <out>. Tokens are left for fill_tree.
compose() {
  local eco="$1" out="$2" mode="$3" v="$4" owner="$5" src
  src="$ECOS/$eco"
  [ -d "$src/template" ] || { echo "no template for ecosystem: $eco" >&2; return 1; }
  [ -n "$v" ] || v="$(layout_default "$eco")" || { echo "no layouts for ecosystem: $eco" >&2; return 1; }
  layout_file "$eco" "$v" >/dev/null || return 1
  mkdir -p "$out"

  cp -R "$src/template/." "$out/"
  [ ! -d "$src/variant.overlay/$v" ] || cp -R "$src/variant.overlay/$v/." "$out/"

  mkdir -p "$out/.github/ISSUE_TEMPLATE" "$out/.github/workflows" "$out/.github/DISCUSSION_TEMPLATE"
  org_codeowners "$out" || cp "$GOV/.github/CODEOWNERS" "$out/.github/"
  cp "$GOV/.github/PULL_REQUEST_TEMPLATE.md" "$out/.github/"
  cp -R "$GOV/.github/ISSUE_TEMPLATE/." "$out/.github/ISSUE_TEMPLATE/"
  cp -R "$GOV/.github/workflows/." "$out/.github/workflows/"
  [ ! -f "$out/go.mod" ] || cp -R "$GOV/.github/go-workflows/." "$out/.github/workflows/"
  [ ! -f "$out/package.json" ] || cp -R "$GOV/.github/npm-workflows/." "$out/.github/workflows/"
  if [ -f "$src/image.variants" ] && grep -vE '^[[:space:]]*(#|$)' "$src/image.variants" | grep -qx "$v"; then
    cp -R "$GOV/.github/image-workflows/." "$out/.github/workflows/"
  fi
  cp "$GOV/.github/.gitleaks.toml" "$out/.gitleaks.toml"
  cp "$(org_labels)" "$out/.github/labels.yml"
  # An owner that extends a shared release-drafter config needs no local copy.
  [ -n "$(org_setting release-drafter-extends)" ] || cp "$GOV/.github/release-drafter.yml" "$out/.github/"
  cp "$GOV/.github/SECURITY.md" "$GOV/.github/CONTRIBUTING.md" "$GOV/.github/CODE_OF_CONDUCT.md" \
     "$GOV/.github/SUPPORT.md" "$out/.github/"
  org_funding "$out"
  cp -R "$GOV/.github/DISCUSSION_TEMPLATE/." "$out/.github/DISCUSSION_TEMPLATE/"
  cp "$GOV/CLAUDE.repo.template.md" "$out/CLAUDE.md"
  layout_render "$out/CLAUDE.md" "$eco" "$v"
  cp "$GOV/AGENTS.repo.template.md" "$out/AGENTS.md"
  eco_governance "$eco" "$out"
  org_skip "$out"

  if [ "$mode" = private ] && [ -d "$src/private.overlay" ] && [ -n "$(ls -A "$src/private.overlay" 2>/dev/null)" ]; then
    cp -R "$src/private.overlay/." "$out/"
  fi

  org_license_text "$out" || return 1
  org_overlay "$out"
  echo "composed $eco/$v ($mode${owner:+, owner $owner}) -> $out"
}

# --- lay the shared governance into an existing repo ---------------------------------------------

# apply_overlay: lay the shared governance into the current directory (a repo clone). Needs
# org_env first. Additive: the repo's own files are kept, except the shared ones it replaces.
apply_overlay() {
  local spec msg p
  mkdir -p .github/ISSUE_TEMPLATE .github/workflows .github/DISCUSSION_TEMPLATE

  # CODEOWNERS: the owner's baseline lines, or else a root owner rule; other lines are kept.
  if org_codeowners .; then
    :
  elif [ -f .github/CODEOWNERS ]; then
    if ! grep -qE '^\*[[:space:]]+@' .github/CODEOWNERS; then
      { echo "# The operator owns and reviews everything by default."
        echo "* @${OWNER}"; echo; cat .github/CODEOWNERS; } > .github/CODEOWNERS.tmp
      mv .github/CODEOWNERS.tmp .github/CODEOWNERS
    fi
  else
    cp "$GOV/.github/CODEOWNERS" .github/CODEOWNERS
  fi

  cp "$GOV/.github/PULL_REQUEST_TEMPLATE.md" .github/PULL_REQUEST_TEMPLATE.md
  [ -f .github/ISSUE_TEMPLATE/config.yml ] || cp "$GOV/.github/ISSUE_TEMPLATE/config.yml" .github/ISSUE_TEMPLATE/config.yml
  cp "$(org_labels)" .github/labels.yml
  if [ -n "$RELEASE_DRAFTER_EXTENDS" ]; then rm -f .github/release-drafter.yml
  else cp "$GOV/.github/release-drafter.yml" .github/release-drafter.yml; fi
  cp "$GOV/.github/.gitleaks.toml" ./.gitleaks.toml
  cp -R "$GOV/.github/workflows/." .github/workflows/
  # Go repos: a repo that still carries the older, possibly adapted scan-security.yml keeps it
  # instead of job-go-security.yaml, so the two scans never run side by side.
  if [ -f go.mod ]; then
    for p in "$GOV"/.github/go-workflows/*.yaml; do
      if [ "$(basename "$p")" = job-go-security.yaml ] && [ -f .github/workflows/scan-security.yml ]; then
        continue
      fi
      cp "$p" .github/workflows/
    done
  fi
  [ ! -f package.json ] || cp -R "$GOV/.github/npm-workflows/." .github/workflows/

  # Workflows and configs that were folded into others or retired.
  rm -f .github/workflows/job-autolabel.yaml .github/workflows/job-gitleaks.yaml \
    .github/workflows/job-license-check.yaml .github/dependabot.yml \
    .github/workflows/job-dependabot-auto-merge.yaml

  cp "$GOV/.github/SECURITY.md" "$GOV/.github/CONTRIBUTING.md" "$GOV/.github/CODE_OF_CONDUCT.md" \
     "$GOV/.github/SUPPORT.md" .github/
  org_funding .
  cp -R "$GOV/.github/DISCUSSION_TEMPLATE/." .github/DISCUSSION_TEMPLATE/

  # The layout block is chosen per repo: read the choice before the template replaces CLAUDE.md,
  # then render it again. A repo that never chose one gets no block; an unusable marker fails.
  spec="$(layout_spec CLAUDE.md 2>&1)" || { echo "ERROR: $OWNER/$REPO_NAME: $spec" >&2; return 1; }
  cp "$GOV/CLAUDE.repo.template.md" CLAUDE.md
  if [ -n "$spec" ]; then
    case "$spec" in
      */*) msg="$(layout_render CLAUDE.md "${spec%%/*}" "${spec#*/}" 2>&1)" ;;
      *)   msg="$(layout_render CLAUDE.md "$spec" 2>&1)" ;;
    esac || {
      echo "ERROR: $OWNER/$REPO_NAME: CLAUDE.md layout marker <!-- layout:begin $spec -->: $msg" >&2
      return 1
    }
    eco_governance "${spec%%/*}" .
  else
    layout_strip CLAUDE.md
  fi
  [ -f AGENTS.md ] || cp "$GOV/AGENTS.repo.template.md" AGENTS.md
  org_skip . "$REPO_NAME"

  while IFS= read -r -d '' p; do fill_file "$p"; done \
    < <(find .github CLAUDE.md AGENTS.md .gitleaks.toml -type f -print0 2>/dev/null)

  # Whitelist-style .gitignore: re-include the governance files git would drop.
  if [ -f .gitignore ]; then
    if git check-ignore -q .claude 2>/dev/null; then
      {
        echo ""
        echo "# Track the shared Claude settings; other .claude files stay local."
        echo "!/.claude/"
        echo "/.claude/*"
        echo "!/.claude/settings.json"
        echo "!/.claude/linux-only"
      } >> .gitignore
    fi
    for p in CLAUDE.md .gitleaks.toml; do
      if git check-ignore -q "$p" 2>/dev/null; then
        printf '\n# Track shared governance file.\n!/%s\n' "$p" >> .gitignore
      fi
    done
  fi

  if [ -f .gitignore ]; then
    grep -qxF "$NOTES_DIR" .gitignore || printf '\n# Local design notes (non-tracked).\n%s\n' "$NOTES_DIR" >> .gitignore
  else
    printf '# Local design notes (non-tracked).\n%s\n' "$NOTES_DIR" > .gitignore
  fi
}
