ARG BASE_TAG=latest
FROM ghcr.io/janrk/debian-trixie-base:${BASE_TAG}

ARG POWERSHELL_VERSION
RUN set -eux; \
    [ -n "${POWERSHELL_VERSION}" ] || { echo "ERROR: POWERSHELL_VERSION build arg is required" >&2; exit 1; }; \
    arch="$(dpkg --print-architecture)"; \
    case "${arch}" in amd64|arm64) ;; *) echo "ERROR: unsupported Debian architecture: ${arch}" >&2; exit 1 ;; esac; \
    package="powershell_${POWERSHELL_VERSION}-1.deb_${arch}.deb"; \
    release_url="https://github.com/PowerShell/PowerShell/releases/download/v${POWERSHELL_VERSION}"; \
    apt-get update; \
    wget --quiet --output-document="/tmp/${package}" "${release_url}/${package}"; \
    wget --quiet --output-document=/tmp/hashes.sha256 "${release_url}/hashes.sha256"; \
    iconv -f UTF-16 -t UTF-8 /tmp/hashes.sha256 | tr -d '\r' | grep -F " *${package}" > /tmp/powershell-package.sha256; \
    (cd /tmp && sha256sum --check --status powershell-package.sha256); \
    dpkg --install "/tmp/${package}" || apt-get install --fix-broken --yes --no-install-recommends; \
    rm -rf /var/lib/apt/lists/* /tmp/hashes.sha256 /tmp/powershell-package.sha256 "/tmp/${package}"; \
    installed_version="$(pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()')"; \
    [ "${installed_version}" = "${POWERSHELL_VERSION}" ] || { echo "ERROR: expected PowerShell ${POWERSHELL_VERSION}, found ${installed_version}" >&2; exit 1; }