FROM python:3.12-slim AS source

# Upstream protocol implementation (MIT): https://github.com/Sophomoresty/gemini-web2api
# Pinned to a reviewed commit; bump deliberately and re-review before changing.
ARG WEB2API_REPO=https://github.com/Sophomoresty/gemini-web2api.git
ARG WEB2API_COMMIT=2bb988bfcbb82a7fab5d2c99aa5560ff40d64f7e

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates \
 && git clone --filter=blob:none "$WEB2API_REPO" /src \
 && git -C /src checkout "$WEB2API_COMMIT"

FROM python:3.12-slim

RUN pip install --no-cache-dir httpx==0.27.2
WORKDIR /app
COPY --from=source /src/gemini_web2api ./gemini_web2api
COPY --from=source /src/LICENSE ./LICENSE.gemini-web2api
COPY launcher.py ./launcher.py

EXPOSE 8081
CMD ["python", "-u", "launcher.py"]
