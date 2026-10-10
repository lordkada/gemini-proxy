#!/bin/sh
# No arguments: serve the Web UI. Otherwise the first argument is a dsh profile
# (headless, acp, ...) and the rest are its own arguments.
set -e
profile="${1:-web}"
[ $# -gt 0 ] && shift
if [ "$profile" = web ]; then
  # Listen on all interfaces of the container (scripts/deepseek-harness.* publish
  # the port on 127.0.0.1 only): the --host flag rejects wildcard addresses, the
  # webserver config does not. Same port inside and outside, so the printed
  # sign-in URL works as is.
  cat > /tmp/dsh-web.yml <<YAML
- id: webserver
  config:
    host: 0.0.0.0
    port: ${DSH_PORT:-3080}
YAML
  set -- --patch /tmp/dsh-web.yml --no-open "$@"
fi
exec dsh --profile "$profile" --patch /etc/dsh/gemini-proxy.yml "$@"
