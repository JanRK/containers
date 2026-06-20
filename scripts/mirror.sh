#!/usr/bin/env bash
# mirror.sh — skopeo-copy a resolved source image to the target registry.
# Handles both version-pinned (copy source:<version>) and digest-tracked
# (copy source@<digest>) jobs. Executes the resolved plan verbatim — no
# substitution (decision 9).
#
# Usage:
#   mirror.sh --plan <desired.json> --image <registry/name> [--result <path>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# Strip a trailing :tag from a registry ref, leaving registry/repo intact.
# A ':' only counts as a tag separator when it appears in the last path
# segment (so registry-host ports like host:5000/x are preserved).
repo_of() {
    local ref="$1" last="${1##*/}"
    case "$last" in
        *:*) printf '%s' "${ref%:*}" ;;
        *)   printf '%s' "$ref" ;;
    esac
}

main() {
    local plan="" image="" result=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --plan)   plan="$2";   shift 2 ;;
            --image)  image="$2";  shift 2 ;;
            --result) result="$2"; shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$plan" ]  || die "--plan is required"
    [ -n "$image" ] || die "--image is required"
    [ -f "$plan" ]  || die "plan not found: $plan"
    require_cmd jq skopeo

    local source target_tag digest
    source="$(json_req "$plan" '.source' source)"
    target_tag="$(json_req "$plan" '.targetTag' targetTag)"
    digest="$(jq -r '.digest // empty' "$plan")"

    # Resolve the source reference: digest-tracked pins by @sha256, version
    # pinned copies the source tag as-is.
    local src_ref
    if [ -n "$digest" ]; then
        src_ref="$(repo_of "$source")@$digest"
    else
        src_ref="$source"
    fi

    log "mirror $src_ref -> $image:$target_tag"
    skopeo copy --all --retry-times 3 "docker://$src_ref" "docker://$image:$target_tag"

    # Apply extra tags by copying the freshly pushed target to each alias.
    local t
    while IFS= read -r t; do
        [ -n "$t" ] || continue
        log "tag $image:$target_tag -> $image:$t"
        skopeo copy --all --retry-times 3 "docker://$image:$target_tag" "docker://$image:$t"
    done < <(jq -r '.extraTags[]?' "$plan")

    [ -n "$result" ] && emit_result "$plan" "$image" "$target_tag" "$result"
    return 0
}

main "$@"
