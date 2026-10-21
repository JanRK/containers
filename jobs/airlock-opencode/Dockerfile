ARG BASE_TAG=latest
FROM ghcr.io/janrk/airlock-base:${BASE_TAG}

ARG OPENCODE_VERSION

RUN set -eux; \
    [ -n "${OPENCODE_VERSION}" ] || { echo "ERROR: OPENCODE_VERSION build arg is required" >&2; exit 1; }; \
    opencode_version="${OPENCODE_VERSION#v}"; \
    { dpkg --compare-versions "${opencode_version}" ge 2.0.25 && dpkg --compare-versions "${opencode_version}" lt 3; } \
        || { echo "ERROR: OpenCode 2.0.25 or later, below 3, is required (anomalyco/opencode#52926), found ${opencode_version}" >&2; exit 1; }; \
    curl -fsSL "https://registry.npmjs.org/@opencode/cli-linux-x64/${opencode_version}" --output /tmp/opencode-package.json; \
    opencode_integrity="$(jq -r '.dist.integrity' /tmp/opencode-package.json)"; \
    opencode_tarball="$(jq -r '.dist.tarball' /tmp/opencode-package.json)"; \
    case "${opencode_integrity}" in sha512-*) ;; *) echo "ERROR: expected a sha512 dist.integrity, found ${opencode_integrity}" >&2; exit 1 ;; esac; \
    curl -fsSL "${opencode_tarball}" --output /tmp/opencode-linux-x64.tgz; \
    printf '%s  %s\n' "$(printf '%s' "${opencode_integrity#sha512-}" | base64 -d | od -An -vtx1 | tr -d ' \n')" \
        /tmp/opencode-linux-x64.tgz > /tmp/opencode.sha512; \
    sha512sum --check /tmp/opencode.sha512; \
    tar -xzf /tmp/opencode-linux-x64.tgz -C /tmp package/bin/opencode; \
    install -m 0755 /tmp/package/bin/opencode /usr/local/bin/opencode; \
    rm -rf /tmp/package /tmp/opencode-linux-x64.tgz /tmp/opencode.sha512 /tmp/opencode-package.json