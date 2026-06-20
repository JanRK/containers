FROM debian:trixie-slim

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates jq openssh-client xz-utils ripgrep ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install multica CLI
ARG MULTICA_VERSION=latest
RUN set -e; \
    ARCH=$(dpkg --print-architecture); \
    if [ "$MULTICA_VERSION" = "latest" ]; then \
      LATEST=$(curl -sI https://github.com/multica-ai/multica/releases/latest | grep -i '^location:' | sed 's/.*tag\///' | tr -d '\r\n'); \
    else \
      LATEST="${MULTICA_VERSION#v}"; LATEST="v${LATEST}"; \
    fi; \
    VERSION="${LATEST#v}"; \
    curl -sL "https://github.com/multica-ai/multica/releases/download/${LATEST}/multica-cli-${VERSION}-linux-${ARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin multica; \
    chmod +x /usr/local/bin/multica

# Install OpenCode (pinned via OPENCODE_VERSION for tag honesty — decision 13: the
# published -o<opencode> tag component must reflect the binary actually baked in,
# so resolve "latest" to its concrete release tag instead of pulling the moving asset).
ARG OPENCODE_VERSION=latest
RUN set -e; \
    ARCH=$(dpkg --print-architecture); \
    if [ "$ARCH" = "amd64" ]; then ARCH="x64"; fi; \
    if [ "$OPENCODE_VERSION" = "latest" ]; then \
      OPENCODE_TAG=$(curl -sI https://github.com/anomalyco/opencode/releases/latest | grep -i '^location:' | sed 's/.*tag\///' | tr -d '\r\n'); \
    else \
      OPENCODE_TAG="${OPENCODE_VERSION#v}"; OPENCODE_TAG="v${OPENCODE_TAG}"; \
    fi; \
    curl -sL "https://github.com/anomalyco/opencode/releases/download/${OPENCODE_TAG}/opencode-linux-${ARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin opencode; \
    chmod +x /usr/local/bin/opencode

# Install Hermes agent (full install via official script, pinned to a release tag)
ARG HERMES_VERSION=latest
RUN set -e; \
    if [ "$HERMES_VERSION" = "latest" ]; then \
      HERMES_TAG=$(curl -fsSL https://api.github.com/repos/NousResearch/hermes-agent/releases/latest | jq -r '.tag_name'); \
      if [ -z "$HERMES_TAG" ] || [ "$HERMES_TAG" = "null" ]; then \
        echo "ERROR: Could not determine latest hermes-agent release"; exit 1; \
      fi; \
    else \
      HERMES_TAG="${HERMES_VERSION#v}"; HERMES_TAG="v${HERMES_TAG}"; \
    fi; \
    echo "Installing hermes-agent ${HERMES_TAG}"; \
    curl -fsSL "https://raw.githubusercontent.com/NousResearch/hermes-agent/${HERMES_TAG}/scripts/install.sh" \
      | bash -s -- --skip-setup --skip-browser

# Create non-root user
RUN useradd -m -s /bin/bash multica
USER multica
WORKDIR /home/multica

# Workspace directory
RUN mkdir -p /home/multica/multica_workspaces

ENV MULTICA_WORKSPACES_ROOT=/home/multica/multica_workspaces \
    MULTICA_OPENCODE_PATH=/usr/local/bin/opencode

ENTRYPOINT ["sh", "-c", "\
  if [ ! -f ~/.multica/config.json ]; then \
    echo ''; \
    echo '=== Multica not authenticated ==='; \
    echo 'Run: docker exec -it <container> multica login'; \
    echo 'Note: port-forward the port shown in the callback URL to this container'; \
    echo ''; \
    echo 'Waiting for ~/.multica/config.json ...'; \
    while [ ! -f ~/.multica/config.json ]; do sleep 5; done; \
  fi; \
  exec multica daemon start --foreground"]
