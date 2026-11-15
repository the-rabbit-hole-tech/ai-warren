#!/usr/bin/env bash
# block-hook-bypass denies a git command that would skip or replace the git hooks: --no-verify, the
# commit short flag -n, and a core.hooksPath override or write. The identity guard and the scrub
# gate are git hooks, so going around them is the same as turning the guard off.
source "$(dirname "$0")/../assert.sh"
g="$PLUGIN/hooks/block-hook-bypass.sh"
run() { out=$(jq -n --arg c "$1" '{tool_input:{command:$c}}' | "$g"); }
deny() { if printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
allow() { if [ -z "$out" ]; then ok "$1"; else bad "$1"; echo "$out"; fi; }

# --no-verify, on any git subcommand that has it
run "git commit --no-verify -m 'fix: x'"; deny "commit --no-verify is denied"
run "git push --no-verify origin main"; deny "push --no-verify is denied"
run "git merge --no-verify topic"; deny "merge --no-verify is denied"
run "git rebase --no-verify main"; deny "rebase --no-verify is denied"
run "git -C /tmp/repo commit --no-verify -m 'fix: x'"; deny "--no-verify after -C is denied"
run "git add . && git commit --no-verify -m 'fix: x'"; deny "--no-verify after && is denied"
run "git status; git push --no-verify"; deny "--no-verify after ; is denied"
run "git log | head; git commit --no-verify -m 'fix: x'"; deny "--no-verify after a pipe is denied"
run "/usr/bin/git commit --no-verify -m 'fix: x'"; deny "a full path to git is checked"
run "xargs git commit --no-verify"; deny "git behind xargs is checked"

# commit -n and its clusters, but not -n where it is not the commit flag
run "git commit -n -m 'fix: x'"; deny "commit -n is denied"
run "git commit -nm 'fix: x'"; deny "commit -nm is denied"
run "git commit -an -m 'fix: x'"; deny "commit -an is denied"
run "git commit -m 'fix: x' -n"; deny "commit -n after the message is denied"
run "git commit -mnote"; allow "the n inside a -m value is not a flag"
run "git push -n origin main"; allow "push -n is a dry run"
run "git log -n 5"; allow "log -n is a count"
run "git push --dry-run origin main"; allow "push --dry-run is allowed"

# core.hooksPath
run "git -c core.hooksPath=/dev/null commit -m 'fix: x'"; deny "-c core.hooksPath is denied"
run "git -c core.hookspath=/tmp/h push"; deny "-c core.hookspath in any case is denied"
run "git --config-env=core.hooksPath=HOOKS commit -m 'fix: x'"; deny "--config-env core.hooksPath is denied"
run "git config core.hooksPath /tmp/h"; deny "git config writing core.hooksPath is denied"
run "git config --global core.hooksPath /tmp/h"; deny "git config --global writing core.hooksPath is denied"
run "git config --unset core.hooksPath"; deny "git config --unset core.hooksPath is denied"
run "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/tmp/h git commit -m 'fix: x'"; deny "a core.hooksPath set through the environment is denied"
run "git config core.hooksPath"; allow "reading core.hooksPath is allowed"
run "git config --get core.hooksPath"; allow "git config --get core.hooksPath is allowed"
run "git config --global --get core.hooksPath"; allow "git config --global --get core.hooksPath is allowed"
run "git config --list"; allow "git config --list is allowed"
run "git config user.name"; allow "other config reads are allowed"

# nested shells
run "bash -c 'git commit --no-verify -m \"fix: x\"'"; deny "bash -c is looked into"
run "sh -c \"git push --no-verify\""; deny "sh -c is looked into"
run "zsh -lc 'git -c core.hooksPath=/dev/null commit -m x'"; deny "zsh -lc is looked into"
run "eval \"git push --no-verify\""; deny "eval is looked into"

# what cannot be parsed but plainly names the bypass is denied: a guard that cannot verify blocks
run "git commit --no-verify -m 'fix: unbalanced"; deny "an unparseable command with --no-verify is denied"
run "git -c core.hooksPath=/dev/null commit -m 'fix: unbalanced"; deny "an unparseable command with core.hooksPath is denied"
run "echo 'unbalanced"; allow "an unparseable command with no bypass is left alone"

# text that only mentions the flag is not a bypass
run "git commit -m 'docs: explain why --no-verify is not allowed'"; allow "a message that mentions --no-verify is allowed"
run "git commit -m 'fix: never set core.hooksPath'"; allow "a message that mentions core.hooksPath is allowed"
run "gh pr create --title 'fix: x' --body 'never use --no-verify'"; allow "a PR body that mentions --no-verify is allowed"
run "echo --no-verify"; allow "echo of the flag is allowed"
run "grep -rn -e --no-verify docs"; allow "grep for the flag is allowed"
run "cat > note.md <<'EOF'
git commit --no-verify
EOF"; allow "a heredoc body that mentions the command is allowed"

# ordinary git stays untouched
run "git commit -m 'fix: x'"; allow "a plain commit is allowed"
run "git commit -am 'fix: x'"; allow "commit -am is allowed"
run "git push origin main"; allow "a plain push is allowed"
run "git status"; allow "git status is allowed"
run "ls -la"; allow "other commands are not checked"
run "git -c user.name=x log"; allow "-c with another key is allowed"
finish
