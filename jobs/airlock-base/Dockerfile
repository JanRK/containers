ARG BASE_TAG=latest
FROM ghcr.io/janrk/pwsh-slim:${BASE_TAG}

ARG AOE_VERSION
ARG MISE_VERSION

RUN set -eux; \
    [ -n "${AOE_VERSION}" ] || { echo "ERROR: AOE_VERSION build arg is required" >&2; exit 1; }; \
    [ -n "${MISE_VERSION}" ] || { echo "ERROR: MISE_VERSION build arg is required" >&2; exit 1; }; \
    apt-get update; \
    apt-get install --yes --no-install-recommends ca-certificates curl git gzip openssh-client ripgrep tar tini tmux; \
    rm -rf /var/lib/apt/lists/*; \
    aoe_version="${AOE_VERSION#v}"; \
    aoe_url="https://github.com/agent-of-empires/agent-of-empires/releases/download/v${aoe_version}"; \
    curl -fsSL "${aoe_url}/aoe-linux-amd64.tar.gz" --output /tmp/aoe-linux-amd64.tar.gz; \
    curl -fsSL "${aoe_url}/aoe-linux-amd64.tar.gz.sha256" --output /tmp/aoe-linux-amd64.tar.gz.sha256; \
    (cd /tmp && sha256sum --check aoe-linux-amd64.tar.gz.sha256); \
    tar -xzf /tmp/aoe-linux-amd64.tar.gz -C /tmp aoe-linux-amd64; \
    install -m 0755 /tmp/aoe-linux-amd64 /usr/local/bin/aoe; \
    mise_version="${MISE_VERSION#v}"; \
    mise_archive="mise-v${mise_version}-linux-x64.tar.gz"; \
    mise_url="https://github.com/jdx/mise/releases/download/v${mise_version}"; \
    curl -fsSL "${mise_url}/${mise_archive}" --output "/tmp/${mise_archive}"; \
    curl -fsSL "${mise_url}/SHASUMS256.txt" --output /tmp/mise-SHASUMS256.txt; \
    grep -E "^[[:xdigit:]]{64}[[:space:]]+(\./)?${mise_archive}$" /tmp/mise-SHASUMS256.txt > /tmp/mise.sha256; \
    test -s /tmp/mise.sha256; \
    (cd /tmp && sha256sum --check mise.sha256); \
    tar -xzf "/tmp/${mise_archive}" -C /tmp mise/bin/mise; \
    install -m 0755 /tmp/mise/bin/mise /usr/local/bin/mise; \
    rm -rf /tmp/aoe-linux-amd64 /tmp/aoe-linux-amd64.tar.gz /tmp/aoe-linux-amd64.tar.gz.sha256 \
        /tmp/mise /tmp/mise-SHASUMS256.txt /tmp/mise.sha256 "/tmp/${mise_archive}"

COPY airlock-setup airlock-entrypoint airlock-render-config /usr/local/bin/

RUN chmod 0755 /usr/local/bin/airlock-setup /usr/local/bin/airlock-entrypoint /usr/local/bin/airlock-render-config \
    && mkdir -p /usr/local/share/airlock \
    && printf '%s\n' airlock-base > /usr/local/share/airlock/image-family \
    && sh -n /usr/local/bin/airlock-setup \
    && sh -n /usr/local/bin/airlock-entrypoint \
    && sh -n /usr/local/bin/airlock-render-config

ENV AIRLOCK_IMAGE_FAMILY=airlock-base \
    MISE_DATA_DIR=/workspace/.airlock/runtimes \
    MISE_CACHE_DIR=/workspace/.airlock/cache \
    PATH="/workspace/.airlock/runtimes/shims:/usr/local/bin:${PATH}"

WORKDIR /workspace
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/airlock-entrypoint"]
CMD ["aoe", "serve"]
