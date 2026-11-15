#!/usr/bin/env bash
# Usage: open-ide.sh <repo-dir>   Opens a repo in GoLand (go.mod) or WebStorm (package.json / anything else).
r=$(cd "$1" && pwd)
if [ -f "$r/go.mod" ] || [ -f "$r/go.work" ]; then app=GoLand; else app=WebStorm; fi
open -a "$app" "$r" && echo "opened $(basename "$(dirname "$r")")/$(basename "$r") in $app"
