ARG CAMOFOX_VERSION
FROM ghcr.io/jo-inc/camofox-browser:${CAMOFOX_VERSION}

ARG CAMOFOX_VERSION
ARG SUPERGATEWAY_VERSION

RUN set -eux; \
    [ -n "${SUPERGATEWAY_VERSION}" ] || { echo "ERROR: SUPERGATEWAY_VERSION build arg is required" >&2; exit 1; }; \
    adapter_version="$(node -p "require('/app/mcp/package.json').version")"; \
    [ "${adapter_version}" = "${CAMOFOX_VERSION}" ] || { echo "ERROR: /app/mcp is ${adapter_version}, image is ${CAMOFOX_VERSION}" >&2; exit 1; }; \
    npm install --global "supergateway@${SUPERGATEWAY_VERSION}"; \
    npm cache clean --force
