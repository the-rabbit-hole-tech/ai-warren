# __REPO_NAME__ 🪝

> 🧭 __DESCRIPTION__

## 📦 Install

Needs bash and `jq`; runs on macOS and Linux.

```bash
bash install.sh
```

`install.sh` copies `__SCRIPT_NAME__.sh` into `~/.claude/hooks/` (or `$CLAUDE_CONFIG_DIR/hooks/`)
and prints the snippet to add to `settings.json`. It never edits `settings.json` itself.

## 🛠 Develop

```bash
task lint    # shellcheck over every script
task test    # tests/run.sh: every tests/*.test.sh, each in a temporary HOME
```

## ⚖️ License

__LICENSE__ (c) __YEAR__ __AUTHOR__
