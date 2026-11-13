# syntax=docker/dockerfile:1
#
# actions-runner — execution image for the Forgejo "sync-and-check" workflow.
#
# FROM pwsh-slim, which already carries curl, wget, ca-certificates, PowerShell and the
# Pester, PSScriptAnalyzer and powershell-yaml modules the check and gate need. This
# layer adds only the remaining tooling, so the 6-hourly run never apt-installs or hits
# PSGallery at runtime (decision 6).

ARG BASE_TAG=latest
FROM ghcr.io/janrk/pwsh-slim:${BASE_TAG}

# OS tooling from Debian (git, openssh-client, skopeo, jq, rsync, bats) plus gh from
# GitHub's OFFICIAL apt repo. The community Debian `gh` package is deliberately NOT used:
# as of Nov 2025 it ships a broken 2.45.x/2.46.x built against deprecated GitHub APIs.
# openssh-client is required: the workflow authenticates the GitHub mirror push with an
# SSH deploy key (ssh-keyscan + `git clone git@github.com:...`). bats is the shell-script
# test runner for stage 4 of check/Invoke-Gate.ps1.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bats \
        git \
        jq \
        openssh-client \
        rsync \
        skopeo; \
    install -d -m 0755 /etc/apt/keyrings; \
    wget -nv -O /etc/apt/keyrings/githubcli-archive-keyring.gpg \
        https://cli.github.com/packages/githubcli-archive-keyring.gpg; \
    chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg; \
    install -d -m 0755 /etc/apt/sources.list.d; \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        > /etc/apt/sources.list.d/github-cli.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends gh; \
    apt-get purge -y --auto-remove; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    git --version; skopeo --version; gh --version; jq --version; rsync --version | head -n1; ssh -V; bats --version

# mikefarah's yq, for the gate: github/scripts/detect-jobs.sh shells out to `yq`, so its
# bats suite cannot run without it. Debian's `yq` package is the unrelated Python one,
# hence the release binary, verified against the release's own checksums.
ARG YQ_VERSION
RUN set -eux; \
    [ -n "${YQ_VERSION}" ] || { echo "ERROR: YQ_VERSION build arg is required" >&2; exit 1; }; \
    arch="$(dpkg --print-architecture)"; \
    yq_url="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION#v}"; \
    curl -fsSL "${yq_url}/yq_linux_${arch}" --output "/tmp/yq_linux_${arch}"; \
    curl -fsSL "${yq_url}/checksums-bsd" --output /tmp/yq-checksums-bsd; \
    grep -E "^SHA256 \(yq_linux_${arch}\) = [[:xdigit:]]{64}$" /tmp/yq-checksums-bsd > /tmp/yq.sha256; \
    test -s /tmp/yq.sha256; \
    (cd /tmp && sha256sum --check yq.sha256); \
    install -m 0755 "/tmp/yq_linux_${arch}" /usr/local/bin/yq; \
    rm -f "/tmp/yq_linux_${arch}" /tmp/yq-checksums-bsd /tmp/yq.sha256; \
    yq --version
