ARG BASE_TAG=latest
FROM ghcr.io/janrk/airlock-base:${BASE_TAG}

ARG OPENCODE_VERSION
ARG NODE_VERSION

RUN set -eux; \
    [ -n "${OPENCODE_VERSION}" ] || { echo "ERROR: OPENCODE_VERSION build arg is required" >&2; exit 1; }; \
    [ -n "${NODE_VERSION}" ] || { echo "ERROR: NODE_VERSION build arg is required" >&2; exit 1; }; \
    apt-get update; \
    apt-get install --yes --no-install-recommends libatomic1 xz-utils; \
    rm -rf /var/lib/apt/lists/*; \
    opencode_version="${OPENCODE_VERSION#v}"; \
    dpkg --compare-versions "${opencode_version}" ge 1.16.0 || { echo "ERROR: OpenCode 1.16.0 or later is required, found ${opencode_version}" >&2; exit 1; }; \
    opencode_url="https://github.com/anomalyco/opencode/releases/download/v${opencode_version}/opencode-linux-x64.tar.gz"; \
    curl -fsSL "$opencode_url" --output /tmp/opencode-linux-x64.tar.gz; \
    tar -xzf /tmp/opencode-linux-x64.tar.gz -C /usr/local/bin opencode; \
    chmod 0755 /usr/local/bin/opencode; \
    rm /tmp/opencode-linux-x64.tar.gz; \
    node_version="${NODE_VERSION#v}"; \
    node_archive="node-v${node_version}-linux-x64.tar.xz"; \
    node_url="https://nodejs.org/dist/v${node_version}"; \
    curl -fsSL "${node_url}/${node_archive}" --output "/tmp/${node_archive}"; \
    curl -fsSL "${node_url}/SHASUMS256.txt" --output /tmp/node-SHASUMS256.txt; \
    grep -E "^[[:xdigit:]]{64}[[:space:]]+(\./)?${node_archive}$" /tmp/node-SHASUMS256.txt > /tmp/node.sha256; \
    test -s /tmp/node.sha256; \
    (cd /tmp && sha256sum --check node.sha256); \
    tar -xJf "/tmp/${node_archive}" --strip-components=1 -C /usr/local; \
    rm -f "/tmp/${node_archive}" /tmp/node-SHASUMS256.txt /tmp/node.sha256; \
    node_major="$(node --version | cut -d. -f1 | tr -d v)"; \
    [ "${node_major}" -ge 22 ] || { echo "ERROR: Node.js 22 or later is required, found $(node --version)" >&2; exit 1; }