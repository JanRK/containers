#!/usr/bin/env bash
# smoke-test.sh — run a job's smoke checks against the built image (decision 10).
# Each test entry is { entrypoint, args[], expect? }: the image is run with the
# given entrypoint and args, the run must exit 0, and if `expect` is set the
# combined output must contain it. Native arch only; no tests is a no-op.
#
# Usage:
#   smoke-test.sh --image <ref> [--tests '<json-array>']
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local image="" tests="[]"
    while [ $# -gt 0 ]; do
        case "$1" in
            --image) image="$2"; shift 2 ;;
            --tests) tests="$2"; shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$image" ] || die "--image is required"
    require_cmd jq docker

    # Normalise null/absent to an empty array; reject malformed JSON.
    local count
    count="$(printf '%s' "$tests" | jq -r 'if . == null then 0 else length end')" \
        || die "invalid --tests JSON"

    if [ "$count" -eq 0 ]; then
        log "no smoke tests for $image"
        return 0
    fi

    log "running $count smoke test(s) against $image"
    local i=0
    while [ "$i" -lt "$count" ]; do
        run_one "$image" "$(printf '%s' "$tests" | jq -c ".[$i]")"
        i=$((i + 1))
    done
    return 0
}

run_one() {
    local image="$1" entry="$2"
    local entrypoint expect out
    entrypoint="$(printf '%s' "$entry" | jq -er '.entrypoint')" \
        || die "smoke test entry missing .entrypoint"
    expect="$(printf '%s' "$entry" | jq -r '.expect // empty')"

    local argv=()
    local a
    while IFS= read -r a; do
        argv+=("$a")
    done < <(printf '%s' "$entry" | jq -r '.args[]?')

    log "smoke: $entrypoint ${argv[*]:-}"
    out="$(docker run --rm --entrypoint "$entrypoint" "$image" "${argv[@]}")" \
        || die "smoke test failed (non-zero exit): $entrypoint ${argv[*]:-}"

    if [ -n "$expect" ]; then
        case "$out" in
            *"$expect"*) : ;;
            *) die "smoke test output missing expected substring '$expect': $entrypoint" ;;
        esac
    fi
}

main "$@"
