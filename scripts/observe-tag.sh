#!/usr/bin/env bash
# observe-tag.sh — the observation adapter, sole caller of `skopeo inspect` (spec 9.3).
#
#   present <digest>   exit 0
#   absent             exit 0   (the registry said manifest unknown)
#   (dies)             exit 1   anything else, stderr attached
#
# Absence exits 0 so no future `|| true` can turn a failed observation into it.
#
# Usage:
#   observe-tag.sh --ref <image:tag>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local ref=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --ref) ref="$2"; shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$ref" ] || die "--ref is required"
    require_cmd skopeo

    local digest
    stderr_file="$(mktemp)"
    trap 'rm -f "$stderr_file"' EXIT
    if digest="$(skopeo inspect --retry-times 3 --format '{{.Digest}}' "docker://$ref" 2>"$stderr_file")"; then
        [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] \
            || die "cannot observe $ref: skopeo exited 0 but printed no digest: '$digest'"
        printf 'present %s\n' "$digest"
        return 0
    fi

    local stderr
    stderr="$(cat "$stderr_file")"
    if [[ "$stderr" == *"manifest unknown"* ]]; then
        log "absent: $ref"
        printf 'absent\n'
        return 0
    fi
    die "cannot observe $ref: ${stderr:-skopeo failed with no stderr}"
}

main "$@"
