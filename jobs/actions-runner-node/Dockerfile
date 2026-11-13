# syntax=docker/dockerfile:1
#
# actions-runner-node — job image for Forgejo workflows that run JavaScript actions
# (actions/checkout) and syntax-check Lua 5.1 sources with `luac -p`.
#
# FROM pwsh-slim, which already carries curl, wget, ca-certificates, PowerShell and the
# Pester, PSScriptAnalyzer and powershell-yaml modules.

ARG BASE_TAG=latest
FROM ghcr.io/janrk/pwsh-slim:${BASE_TAG}

# Classic WoW runs Lua 5.1, so plain `lua` and `luac` are pinned to 5.1 rather than left to alternatives priority.
# libatomic1 is a runtime dependency of the nodejs.org Node.js binaries.
RUN set -eux; \
    apt-get update; \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends git jq libatomic1 lua5.1 openssh-client; \
    update-alternatives --set lua-interpreter /usr/bin/lua5.1; \
    update-alternatives --set lua-compiler /usr/bin/luac5.1; \
    rm -rf /var/lib/apt/lists/*; \
    git --version; jq --version; ssh -V; luac -v

# Node.js from nodejs.org, not Debian's `nodejs`, which lags behind LTS.
ARG NODE_VERSION
RUN set -eux; \
    [ -n "${NODE_VERSION}" ] || { echo "ERROR: NODE_VERSION build arg is required" >&2; exit 1; }; \
    node_version="v${NODE_VERSION#v}"; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in amd64) node_arch=x64 ;; arm64) node_arch=arm64 ;; *) echo "ERROR: unsupported Debian architecture: ${arch}" >&2; exit 1 ;; esac; \
    node_archive="node-${node_version}-linux-${node_arch}.tar.gz"; \
    node_url="https://nodejs.org/dist/${node_version}"; \
    curl -fsSL "${node_url}/${node_archive}" --output "/tmp/${node_archive}"; \
    curl -fsSL "${node_url}/SHASUMS256.txt" --output /tmp/node-SHASUMS256.txt; \
    grep -E "^[[:xdigit:]]{64}[[:space:]]+(\./)?${node_archive}$" /tmp/node-SHASUMS256.txt > /tmp/node.sha256; \
    test -s /tmp/node.sha256; \
    (cd /tmp && sha256sum --check node.sha256); \
    tar -xzf "/tmp/${node_archive}" --strip-components=1 --no-same-owner -C /usr/local; \
    rm -f /usr/local/CHANGELOG.md /usr/local/LICENSE /usr/local/README.md \
        "/tmp/${node_archive}" /tmp/node-SHASUMS256.txt /tmp/node.sha256; \
    [ "$(node --version)" = "${node_version}" ] || { echo "ERROR: expected Node.js ${node_version}, found $(node --version)" >&2; exit 1; }; \
    npm --version

ENV npm_config_update_notifier=false
