#!/usr/bin/env bash
# Shared bats setup for the github/scripts suite.
#
# Provides a fake PATH bin with recording skopeo/docker stubs so command
# construction can be asserted without a real registry or daemon. Behaviour of
# the stubs is driven by env vars set per-test:
#   FAKE_SKOPEO_DIGEST   - digest echoed by `skopeo inspect` (default 64x c)
#   FAKE_SKOPEO_FAIL_ON  - substring; skopeo exits 1 if its args contain it
#   FAKE_SKOPEO_STDERR   - line skopeo prints to stderr when it fails
#   FAKE_DOCKER_FAIL_ON  - substring; docker exits 1 if its args contain it
#   FAKE_DOCKER_RC       - default docker exit code (default 0)
#   FAKE_GIT_FAIL_ON     - substring; git exits 1 if its args contain it
#   FAKE_GIT_MKDIR       - subdirectory `git clone` also creates in the clone

setup() {
    bats_require_minimum_version 1.5.0
    TEST_TMP="$(mktemp -d)"
    FAKE_BIN="$TEST_TMP/bin"
    mkdir -p "$FAKE_BIN"
    CALL_LOG="$TEST_TMP/calls.log"
    : > "$CALL_LOG"
    SCRIPTS_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export TEST_TMP FAKE_BIN CALL_LOG SCRIPTS_DIR

    _make_fake skopeo
    _make_fake docker
    _make_fake git
    export PATH="$FAKE_BIN:$PATH"

    # Deterministic timestamp for result-artifact emission.
    export BUILT_AT="2026-06-20T12:00:00Z"
}

teardown() {
    [ -n "${TEST_TMP:-}" ] && rm -rf "$TEST_TMP"
}

_make_fake() {
    case "$1" in
        skopeo)
            cat > "$FAKE_BIN/skopeo" <<'EOF'
#!/usr/bin/env bash
echo "skopeo $*" >> "$CALL_LOG"
if [ -n "${FAKE_SKOPEO_FAIL_ON:-}" ] && [[ "$*" == *"$FAKE_SKOPEO_FAIL_ON"* ]]; then
  [ -n "${FAKE_SKOPEO_STDERR:-}" ] && echo "$FAKE_SKOPEO_STDERR" >&2
  exit 1
fi
case "$1" in
  inspect) echo "${FAKE_SKOPEO_DIGEST-sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc}";;
esac
exit 0
EOF
            chmod +x "$FAKE_BIN/skopeo"
            ;;
        docker)
            cat > "$FAKE_BIN/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >> "$CALL_LOG"
[ -n "${FAKE_DOCKER_STDOUT:-}" ] && echo "$FAKE_DOCKER_STDOUT"
if [ -n "${FAKE_DOCKER_FAIL_ON:-}" ] && [[ "$*" == *"$FAKE_DOCKER_FAIL_ON"* ]]; then exit 1; fi
exit "${FAKE_DOCKER_RC:-0}"
EOF
            chmod +x "$FAKE_BIN/docker"
            ;;
        git)
            # Records the call and, for `clone`, materialises the destination
            # (last arg) with a Dockerfile so the remote build path is testable.
            cat > "$FAKE_BIN/git" <<'EOF'
#!/usr/bin/env bash
echo "git $*" >> "$CALL_LOG"
if [ -n "${FAKE_GIT_FAIL_ON:-}" ] && [[ "$*" == *"$FAKE_GIT_FAIL_ON"* ]]; then exit 1; fi
if [ "$1" = "clone" ]; then
  for dest in "$@"; do :; done
  mkdir -p "$dest"
  printf 'FROM scratch\n' > "$dest/Dockerfile"
  [ -z "${FAKE_GIT_MKDIR:-}" ] || mkdir -p "$dest/$FAKE_GIT_MKDIR"
fi
exit 0
EOF
            chmod +x "$FAKE_BIN/git"
            ;;
    esac
}

# Assert the recorded call log contains a fixed substring.
log_has() { grep -qF -- "$1" "$CALL_LOG"; }

# Count recorded invocations of a given command word.
log_count() { grep -c -- "^$1 " "$CALL_LOG"; }
