#!/usr/bin/env bash
# should-build.sh — registry-skip guard (decision 3). Re-checks the registry and
# prints "build" or "skip" so a self-healing re-trigger that has already landed
# does not rebuild. Prints exactly one word on stdout; logs go to stderr.
#
# Tracks:
#   version (default) — skip if the target tag exists in the registry at all.
#   digest            — skip only if the target tag's digest equals the plan's
#                       upstream digest; rebuild if it is absent or differs.
#
# Usage:
#   should-build.sh --plan <desired.json> --image <registry/name>
#                   [--track <version|digest>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# Echo the registry digest of a ref, or nothing if it does not exist. Uses the
# ambient registry credentials (docker login) so private targets resolve.
remote_digest() {
    skopeo inspect --retry-times 3 --format '{{.Digest}}' \
        "docker://$1" 2>/dev/null || true
}

main() {
    local plan="" image="" track="version"
    while [ $# -gt 0 ]; do
        case "$1" in
            --plan)  plan="$2";  shift 2 ;;
            --image) image="$2"; shift 2 ;;
            --track) track="$2"; shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$plan" ]  || die "--plan is required"
    [ -n "$image" ] || die "--image is required"
    [ -f "$plan" ]  || die "plan not found: $plan"
    require_cmd jq skopeo

    local target_tag
    target_tag="$(json_req "$plan" '.targetTag' targetTag)"

    local current
    current="$(remote_digest "$image:$target_tag")"

    case "$track" in
        version)
            if [ -n "$current" ]; then
                log "skip: $image:$target_tag already present"
                printf 'skip\n'
            else
                log "build: $image:$target_tag absent"
                printf 'build\n'
            fi
            ;;
        digest)
            local want
            want="$(jq -r '.digest // empty' "$plan")"
            [ -n "$want" ] || die "digest track requires .digest in the plan"
            if [ -z "$current" ]; then
                log "build: $image:$target_tag absent"
                printf 'build\n'
            elif [ "$current" = "$want" ]; then
                log "skip: $image:$target_tag digest matches $want"
                printf 'skip\n'
            else
                log "build: $image:$target_tag digest $current != $want"
                printf 'build\n'
            fi
            ;;
        *)
            die "unknown track: $track (expected version or digest)"
            ;;
    esac
}

main "$@"
