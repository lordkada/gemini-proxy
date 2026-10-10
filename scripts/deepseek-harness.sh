#!/usr/bin/env bash
# Run DeepSeek Harness (dsh) in a container, against the proxy, on the current directory.
# Usage: scripts/deepseek-harness.sh                       Web UI on http://127.0.0.1:3080
#        scripts/deepseek-harness.sh headless "explain this repo"   one-shot task
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE=gemini-proxy-deepseek-harness
NETWORK=gemini-proxy_default
PORT="${DSH_PORT:-3080}"

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
  docker build ${BUILD_NETWORK:+--network "$BUILD_NETWORK"} -t "$IMAGE" "$REPO_DIR/deepseek-harness-container"
fi

# Without a terminal (scripts, CI) attaching stdin would make headless runs wait for input.
TTY_FLAGS=()
[[ -t 0 && -t 1 ]] && TTY_FLAGS=(-it)

# The Web UI is the default; only then is a port published, on 127.0.0.1.
PORT_FLAGS=()
[[ $# -eq 0 || "$1" == web ]] && PORT_FLAGS=(-p "127.0.0.1:$PORT:$PORT" -e DSH_PORT="$PORT")

exec docker run --rm ${TTY_FLAGS[@]+"${TTY_FLAGS[@]}"} ${PORT_FLAGS[@]+"${PORT_FLAGS[@]}"} \
  --network "$NETWORK" \
  --user "$(id -u):$(id -g)" \
  -e GEMINI_PROXY_API_KEY="$API_KEY" \
  -v "$PWD":/work \
  "$IMAGE" "$@"
