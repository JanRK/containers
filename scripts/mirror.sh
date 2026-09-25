#!/usr/bin/env bash
# mirror.sh — skopeo-copy a resolved source image to the target registry.
# --source arrives already pinned — source:<version> or source@<digest> — so
# version and digest tracking copy alike and nothing is joined here. Executes
# the resolved plan verbatim — no substitution (decision 9).
#
# Usage:
#   mirror.sh --source <ref> --image <registry/name> --target-tag <tag>
#             --extra-tags '<json array>'
#             [--result <path> --name <job> --resolved '<json object>']
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local source="" image="" target_tag="" extra_tags="" result="" name="" resolved=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --source)     source="$2";     shift 2 ;;
            --image)      image="$2";      shift 2 ;;
            --target-tag) target_tag="$2"; shift 2 ;;
            --extra-tags) extra_tags="$2"; shift 2 ;;
            --result)     result="$2";     shift 2 ;;
            --name)       name="$2";       shift 2 ;;
            --resolved)   resolved="$2";   shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$source" ]     || die "--source is required"
    [ -n "$image" ]      || die "--image is required"
    [ -n "$target_tag" ] || die "--target-tag is required"
    [ -n "$extra_tags" ] || die "--extra-tags is required"
    if [ -n "$result" ]; then
        [ -n "$name" ]     || die "--name is required with --result"
        [ -n "$resolved" ] || die "--resolved is required with --result"
    fi
    require_cmd jq skopeo

    local tags=()
    jq -e 'type == "array" and all(.[]; type == "string")' <<<"$extra_tags" >/dev/null 2>&1 \
        || die "--extra-tags must be a JSON array of strings: $extra_tags"
    mapfile -t tags < <(jq -r '.[]' <<<"$extra_tags")

    log "mirror $source -> $image:$target_tag"
    skopeo copy --all --retry-times 3 "docker://$source" "docker://$image:$target_tag"

    # Apply extra tags by copying the freshly pushed target to each alias.
    local t
    for t in "${tags[@]}"; do
        log "tag $image:$target_tag -> $image:$t"
        skopeo copy --all --retry-times 3 "docker://$image:$target_tag" "docker://$image:$t"
    done

    if [ -n "$result" ]; then
        bash "$SCRIPT_DIR/emit-result.sh" --name "$name" --image "$image" \
            --built-tag "$target_tag" --resolved "$resolved" > "$result"
        log "wrote result artifact $result"
    fi
    return 0
}

main "$@"
