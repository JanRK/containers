FROM debian:trixie-slim

# System deps. tini is the PID-1 init for the long-running server (reaps zombies and
# forwards SIGTERM for a graceful shutdown); git/openssh-client/ripgrep/ca-certificates
# are what opencode needs to operate on repositories. curl is the build-time fetcher.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git ca-certificates openssh-client ripgrep tini \
    && rm -rf /var/lib/apt/lists/*

# Install OpenCode. OPENCODE_VERSION is REQUIRED and supplied by the check as a
# concrete release (decision 13: the check resolves anomalyco/opencode's latest
# release — e.g. 1.17.8 — so the published v<opencode> tag is honest). The build
# bakes exactly that release: there is no "latest" auto-resolution here, so the image
# never fetches a moving asset. Manual build: --build-arg OPENCODE_VERSION=1.17.8
ARG OPENCODE_VERSION
RUN set -e; \
    [ -n "$OPENCODE_VERSION" ] || { echo "ERROR: OPENCODE_VERSION build arg is required"; exit 1; }; \
    ARCH=$(dpkg --print-architecture); \
    if [ "$ARCH" = "amd64" ]; then ARCH="x64"; fi; \
    OPENCODE_TAG="v${OPENCODE_VERSION#v}"; \
    curl -fsSL "https://github.com/anomalyco/opencode/releases/download/${OPENCODE_TAG}/opencode-linux-${ARCH}.tar.gz" \
      | tar -xz -C /usr/local/bin opencode; \
    chmod +x /usr/local/bin/opencode

# Non-root runtime user.
RUN useradd -m -s /bin/bash opencode
USER opencode
WORKDIR /home/opencode

# Host/port are env vars so they can be overridden at `docker run` (-e ...). The
# default hostname is 127.0.0.1 (loopback only) so the server is NOT reachable from
# outside the container unless the operator opts in with -e OPENCODE_HOSTNAME=0.0.0.0
# — secure by default. The CMD runs under a shell so $OPENCODE_HOSTNAME/$OPENCODE_PORT
# expand at runtime; `exec` hands PID 1 (tini) the opencode process for clean signals.
ENV OPENCODE_HOSTNAME=127.0.0.1 \
    OPENCODE_PORT=4096
EXPOSE 4096
ENTRYPOINT ["tini", "--"]
CMD ["sh", "-c", "exec opencode serve --hostname \"$OPENCODE_HOSTNAME\" --port \"$OPENCODE_PORT\""]
