#!/usr/bin/env bash
# should-build.sh — registry-skip guard (decision 3). Re-checks the registry and
# prints decision=build or decision=skip so a self-healing re-trigger that has
# already landed does not rebuild. One key=value line on stdout, for the
# workflow to redirect into $GITHUB_OUTPUT; logs go to stderr.
#
# Tracks:
#   version — skip if the target tag exists in the registry at all.
#   digest  — skip only if the target tag's digest equals --digest, the plan's
#             upstream digest; rebuild if it is absent or differs.
#
# Usage:
#   should-build.sh --image <registry/name> --target-tag <tag>
#                   --track <version|digest> [--digest <sha256:…>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local image="" target_tag="" track="" want=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --image)      image="$2";      shift 2 ;;
            --target-tag) target_tag="$2"; shift 2 ;;
            --track)      track="$2";      shift 2 ;;
            --digest)     want="$2";       shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$image" ]      || die "--image is required"
    [ -n "$target_tag" ] || die "--target-tag is required"
    [ -n "$track" ]      || die "--track is required"
    case "$track" in
        version) ;;
        digest) [ -n "$want" ] || die "digest track requires --digest" ;;
        *) die "unknown track: $track (expected version or digest)" ;;
    esac

    # Dies rather than build over a tag that may exist: write-once beats one lost tick.
    local observation current=""
    observation="$(bash "$SCRIPT_DIR/observe-tag.sh" --ref "$image:$target_tag")" \
        || die "cannot observe $image:$target_tag, refusing to decide"
    case "$observation" in
        "present "*) current="${observation#present }" ;;
        absent) ;;
        *) die "unrecognised observation of $image:$target_tag: $observation" ;;
    esac

    if [ -z "$current" ]; then
        log "build: $image:$target_tag absent"
        printf 'decision=build\n'
    elif [ "$track" = "version" ]; then
        log "skip: $image:$target_tag already present"
        printf 'decision=skip\n'
    elif [ "$current" = "$want" ]; then
        log "skip: $image:$target_tag digest matches $want"
        printf 'decision=skip\n'
    else
        log "build: $image:$target_tag digest $current != $want"
        printf 'decision=build\n'
    fi
}

main "$@"
