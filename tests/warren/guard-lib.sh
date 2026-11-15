#!/usr/bin/env bash
# Sandbox set-up shared by the guard tests: a throwaway HOME with its own global git config,
# gh config and synced guard, so nothing here reads or changes the real machine's setup.
# Source after assert.sh and needs_sandbox.
#   guard_home <plugin-root> [login]   new HOME, guard synced from <plugin-root>, linked, and
#                                      (with a login) the guard identity set to it
guard_home() {
  local root=$1 login=${2:-}
  export HOME="$TMP/home"
  cd "$TMP" || return 1
  mkdir -p "$HOME/.config/gh" "$HOME/.config/git"
  export GH_CONFIG_DIR="$HOME/.config/gh"
  unset GIT_CONFIG_GLOBAL GIT_AUTHOR_NAME GIT_AUTHOR_EMAIL GIT_COMMITTER_NAME GIT_COMMITTER_EMAIL
  gh_user "${login:-testperson}"
  CLAUDE_PLUGIN_ROOT="$root" "$root/bin/warren-guard-sync" --quiet >/dev/null 2>&1 || true
  ln -sfn "$HOME/.config/warren/git-hooks" "$HOME/.config/git/hooks"
  git config --global core.hooksPath "$HOME/.config/git/hooks"
  git config --global init.defaultBranch main
  if [ -n "$login" ]; then set_identity "$login"; fi
}
# set_identity <login>: the guard identity and the matching git identity for the sandbox person.
set_identity() {
  git config --global guard.expectedLogin "$1"
  git config --global guard.expectedName "$1"
  git config --global hooks.expectedAuthorEmail "1+$1@users.noreply.github.com"
  git config --global user.name "$1"
  git config --global user.email "1+$1@users.noreply.github.com"
}
# gh_user <login>: the account gh reports as active.
# The token is a placeholder: gh only needs one present to read the multi-account format.
gh_user() {
  printf 'github.com:\n    users:\n        %s:\n    user: %s\n    oauth_token: placeholder\n    git_protocol: https\n' \
    "$1" "$1" > "$GH_CONFIG_DIR/hosts.yml"
}
# mkrepo <name>: a repo under $TMP with main pushed to a bare remote under $TMP/remotes.
mkrepo() {
  local r="$TMP/$1" rem="$TMP/remotes/$1.git"
  mkdir -p "$TMP/remotes"; git init -q --bare -b main "$rem"
  git init -q -b main "$r"; echo demo > "$r/README"
  git -C "$r" add README && git -C "$r" commit -q -m "chore: init"
  git -C "$r" remote add origin "file://$rem"
  git -C "$r" push -q origin main 2>/dev/null || echo "setup push failed for $1" >&2
}
