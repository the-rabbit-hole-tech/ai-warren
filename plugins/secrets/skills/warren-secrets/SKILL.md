---
name: warren-secrets
description: Use when the owner runs /secrets:warren-secrets to connect their password manager.
disable-model-invocation: true
---

# Connect your password manager

1. Check that the org or personal plugin that supplies your password manager's MCP server is installed and enabled. If not, say so and stop.
2. Ask for the manager's address if the plugin's user config needs one. Never suggest or ship a default.
3. Have them sign in with `/mcp`.
4. Check the connection with the manager's list tool, and report the result. Never print a credential value.
