ARG BASE_TAG=trixie-slim
FROM ghcr.io/janrk/debian-trixie-slim:${BASE_TAG}

RUN apt-get update \
    && apt-get install --no-install-recommends --yes ca-certificates curl jq \
    && rm -rf /var/lib/apt/lists/* \
    && arch="$(dpkg --print-architecture)" \
    && curl -fsSL "https://github.com/mikefarah/yq/releases/download/v4.53.6/yq_linux_${arch}" \
        --output /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq
