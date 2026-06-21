# routa-extras — overlay ghcr.io/janrk/routa with git + ca-certificates.
#
# The base is built upstream (phodal/routa's node:22-alpine Dockerfile); its
# runner stage ends as the non-root user `nextjs`. We re-enter as root to add
# the two packages, then drop back to `nextjs` so runtime privileges are
# unchanged. ENTRYPOINT/CMD (node server.js, :3000) are inherited from the base.
#
# ROUTA_VERSION is REQUIRED and supplied by the check as a concrete release
# (decision 13). The FROM tag is the real pin — an empty ROUTA_VERSION makes the
# base reference `...:v` which fails to pull; the guard below documents that
# contract explicitly. Manual build: --build-arg ROUTA_VERSION=0.18.1
ARG ROUTA_VERSION
FROM ghcr.io/janrk/routa:v${ROUTA_VERSION}

ARG ROUTA_VERSION
USER root
RUN set -e; \
    [ -n "$ROUTA_VERSION" ] || { echo "ERROR: ROUTA_VERSION build arg is required"; exit 1; }; \
    apk add --no-cache git ca-certificates
USER nextjs
