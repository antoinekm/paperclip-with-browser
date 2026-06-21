# syntax=docker/dockerfile:1.6
#
# Paperclip with a headless Chromium runtime, so agents can use a real browser
# via MCP servers like chrome-devtools-mcp or playwright-mcp.
#
# Upstream image lives at ghcr.io/paperclipai/paperclip (built per master push).
# We use :latest by default. To pin to a specific upstream sha, override the
# BASE_TAG build arg: `docker build --build-arg BASE_TAG=sha-9ac2431 ...`.
ARG BASE_TAG=latest
FROM ghcr.io/paperclipai/paperclip:${BASE_TAG}

# Install Chromium and the runtime libs it needs, plus postgresql-client so
# agents can run psql/pg_dump against managed databases (the Coolify MCP only
# exposes read-only inspect tools, no terminal). We stay as root because the
# upstream image's entrypoint already drops to the `node` user via gosu, and
# the OS-level binaries we add must be owned by root.
USER root
RUN apt-get update \
  && apt-get install -y --no-install-recommends chromium postgresql-client \
  && rm -rf /var/lib/apt/lists/*

# Chromium's user-namespace sandbox cannot initialize inside a non-privileged
# Docker container (you get "Failed to move to new namespace: Operation not
# permitted" -> CDP "Target closed" the moment chrome-devtools-mcp connects).
# The container itself is already the isolation boundary, so we wrap chromium
# to always pass --no-sandbox. MCP configs should point to this wrapper rather
# than /usr/bin/chromium directly.
COPY chromium-headless /usr/local/bin/chromium-headless
RUN chmod +x /usr/local/bin/chromium-headless
