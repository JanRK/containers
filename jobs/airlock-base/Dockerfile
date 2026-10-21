ARG BASE_TAG=latest
FROM ghcr.io/janrk/pwsh-slim:${BASE_TAG}

ARG AOE_VERSION
ARG MISE_VERSION

RUN set -eux; \
    [ -n "${AOE_VERSION}" ] || { echo "ERROR: AOE_VERSION build arg is required" >&2; exit 1; }; \
    [ -n "${MISE_VERSION}" ] || { echo "ERROR: MISE_VERSION build arg is required" >&2; exit 1; }; \
    apt-get update; \
    apt-get install --yes --no-install-recommends bind9-dnsutils ca-certificates curl fd-find file git gzip jq libatomic1 lsof make \
        openssh-client patch procps ripgrep shellcheck tar tini tmux tree xz-utils; \
    rm -rf /var/lib/apt/lists/*; \
    ln -s /usr/bin/fdfind /usr/local/bin/fd; \
    aoe_version="${AOE_VERSION#v}"; \
    dpkg --compare-versions "${aoe_version}" ge 1.20.0 || { echo "ERROR: Agent of Empires 1.20.0 or later is required (agent-of-empires#4307), found ${aoe_version}" >&2; exit 1; }; \
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
    yq_url="https://github.com/mikefarah/yq/releases/latest/download"; \
    curl -fsSL "${yq_url}/yq_linux_amd64" --output /tmp/yq_linux_amd64; \
    curl -fsSL "${yq_url}/checksums-bsd" --output /tmp/yq-checksums-bsd; \
    grep -E '^SHA256 \(yq_linux_amd64\) = [[:xdigit:]]{64}$' /tmp/yq-checksums-bsd > /tmp/yq.sha256; \
    test -s /tmp/yq.sha256; \
    (cd /tmp && sha256sum --check yq.sha256); \
    install -m 0755 /tmp/yq_linux_amd64 /usr/local/bin/yq; \
    node_version="$(curl -fsSL https://nodejs.org/dist/index.json \
        | jq -r '[.[] | select(.lts != false) | .version] | max_by(ltrimstr("v") | split(".") | map(tonumber))')"; \
    printf '%s\n' "${node_version}" | grep -Eqx 'v[0-9]+\.[0-9]+\.[0-9]+' || { echo "ERROR: no Node.js LTS found in the dist index, got '${node_version}'" >&2; exit 1; }; \
    node_archive="node-${node_version}-linux-x64.tar.xz"; \
    node_url="https://nodejs.org/dist/${node_version}"; \
    curl -fsSL "${node_url}/${node_archive}" --output "/tmp/${node_archive}"; \
    curl -fsSL "${node_url}/SHASUMS256.txt" --output /tmp/node-SHASUMS256.txt; \
    grep -E "^[[:xdigit:]]{64}[[:space:]]+(\./)?${node_archive}$" /tmp/node-SHASUMS256.txt > /tmp/node.sha256; \
    test -s /tmp/node.sha256; \
    (cd /tmp && sha256sum --check node.sha256); \
    tar -xJf "/tmp/${node_archive}" --strip-components=1 -C /usr/local; \
    node_major="$(node --version | cut -d. -f1 | tr -d v)"; \
    [ "${node_major}" -ge 22 ] || { echo "ERROR: Node.js 22 or later is required, found $(node --version)" >&2; exit 1; }; \
    rm -rf /tmp/aoe-linux-amd64 /tmp/aoe-linux-amd64.tar.gz /tmp/aoe-linux-amd64.tar.gz.sha256 \
        /tmp/mise /tmp/mise-SHASUMS256.txt /tmp/mise.sha256 "/tmp/${mise_archive}" \
        /tmp/yq_linux_amd64 /tmp/yq-checksums-bsd /tmp/yq.sha256 \
        "/tmp/${node_archive}" /tmp/node-SHASUMS256.txt /tmp/node.sha256

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
