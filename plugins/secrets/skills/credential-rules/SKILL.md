---
name: credential-rules
description: Use when a task needs a credential, API key, SSH key or signing key: where development credentials live, the order to create them, and how to describe a secret.
---

# Credential rules

- **Development credentials live in your password manager:** GitHub and app or release signing keys, API tokens, SSH keys for dev and build hosts and the like. Store them yourself through the manager's MCP server, which your org or personal plugin supplies.
- **Password manager first, then the device:** look in the password manager before authenticating to anything. Create a new credential there first, then set it on the device, never the other way round.
- **Secret descriptions: one line plus labelled notes.** Write each secret's description as one line, then short labelled notes (Host, Port, From, Pin, Set up, Rotate), current facts only. Run-on paragraphs went stale and misled.
- **Speaking to the owner:** call it "your password manager".

See secrets:inject-not-reveal for how a value reaches a program.
