#!/usr/bin/env bash
# Shared helpers for the GitHub build pipeline scripts.
# Source this file; it defines functions only and runs nothing on its own.
#
# Admission rule (ADR-0012): lib.sh may hold only functions with no failure
# mode a test would assert beyond "it printed" or "it exited". Anything with
# real behaviour is an executable with its own bats file. lib.sh therefore has
# no tests; needing one is the sign a function no longer belongs here.

# Log a line to stderr with a ">>" marker so it stands out in CI logs.
log() { printf '>> %s\n' "$*" >&2; }

# Log an error and abort with a non-zero status.
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Abort unless every named command is on PATH.
require_cmd() {
    local c
    for c in "$@"; do
        command -v "$c" >/dev/null 2>&1 || die "required command not found: $c"
    done
}
