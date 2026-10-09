#!/usr/bin/env bash
# Run opencode in a container, against the proxy, on the current directory.
# Usage: scripts/opencode.sh [opencode args...]   e.g. scripts/opencode.sh run "explain this repo"
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE=gemini-proxy-opencode
NETWORK=gemini-proxy_default

if [[ ! -f "$REPO_DIR/.env" ]]; then
  echo "Missing $REPO_DIR/.env: copy .env.example to .env and start the proxy first." >&2
  exit 1
fi
API_KEY="$(grep -E '^PROXY_API_KEY=' "$REPO_DIR/.env" | tail -1 | cut -d= -f2-)"

if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "The proxy is not running: run 'docker compose up -d' in $REPO_DIR first." >&2
  exit 1
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1 || [[ "${REBUILD:-}" == 1 ]]; then
  docker build ${BUILD_NETWORK:+--network "$BUILD_NETWORK"} -t "$IMAGE" "$REPO_DIR/opencode-container"
fi

# Interactive TUI needs a terminal; without one (scripts, CI) attaching stdin would make
# `opencode run` wait for input, so attach nothing.
TTY_FLAGS=()
[[ -t 0 && -t 1 ]] && TTY_FLAGS=(-it)

exec docker run --rm ${TTY_FLAGS[@]+"${TTY_FLAGS[@]}"} \
  --network "$NETWORK" \
  --user "$(id -u):$(id -g)" \
  -e GEMINI_PROXY_API_KEY="$API_KEY" \
  -e TERM="${TERM:-xterm-256color}" \
  -v "$PWD":/work \
  "$IMAGE" "$@"
