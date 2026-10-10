FROM node:22-slim

# Developer preview: pinned because upstream announces breaking changes.
ARG DSH_VERSION=0.2.0-rc.2

RUN npm install -g "@deepseek-ai/dsh@${DSH_VERSION}" \
 && apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates ripgrep python3 \
 && rm -rf /var/lib/apt/lists/*

COPY gemini-proxy.yml /etc/dsh/
COPY entrypoint.sh /usr/local/bin/dsh-entrypoint
ENV HOME=/tmp/home

WORKDIR /work
ENTRYPOINT ["dsh-entrypoint"]
