# A clean Debian machine for the warren init test: only curl, git and CA certificates, plus
# python3, which the guard's pre-push scrub gate runs on. Everything else (tmux, gh, claude, the
# marketplace, the plugin and the guard) is warren's job.
FROM debian:stable-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl git ca-certificates python3 \
 && rm -rf /var/lib/apt/lists/*

COPY warren /usr/local/bin/warren
COPY agent-machine.yaml /test/agent-machine.yaml
COPY in-container.sh /test/in-container.sh
COPY marketplace /test/marketplace

ENV WARREN_MARKETPLACE_SOURCE=/test/marketplace
CMD ["bash", "/test/in-container.sh"]
