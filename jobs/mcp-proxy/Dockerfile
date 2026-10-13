ARG MCP_PROXY_VERSION
ARG UV_VERSION
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

FROM ghcr.io/sparfenyuk/mcp-proxy:v${MCP_PROXY_VERSION}

ARG UV_VERSION

COPY --from=uv /uv /uvx /bin/

RUN set -eu; \
    [ -n "${UV_VERSION}" ] || { echo "ERROR: UV_VERSION build arg is required" >&2; exit 1; }; \
    uv --version | grep -qF "uv ${UV_VERSION}" || { echo "ERROR: expected uv ${UV_VERSION}, found $(uv --version)" >&2; exit 1; }; \
    apk add --no-cache nodejs npm
