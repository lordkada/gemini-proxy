FROM node:22-slim

ARG OPENCODE_VERSION=1.18.35

RUN npm install -g "opencode-ai@${OPENCODE_VERSION}" \
 && apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates ripgrep python3 \
 && rm -rf /var/lib/apt/lists/*

COPY opencode.json /etc/opencode/opencode.json
ENV OPENCODE_CONFIG=/etc/opencode/opencode.json \
    HOME=/tmp/home

WORKDIR /work
ENTRYPOINT ["opencode"]
