#!/usr/bin/env bash
# publish-tags.sh — attach tags to a smoke-tested digest and write its result.
#
# Usage:
#   publish-tags.sh --image <registry/name> --digest <sha256:…> --target-tag <tag>
#                   --extra-tags '<json array>' --name <job> --resolved '<json object>'
#                   --recipe-digest <sha256:…> --result <path>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local image="" digest="" target_tag="" extra_tags="" name=""
    local resolved="" recipe_digest="" result=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --image)         image="$2";         shift 2 ;;
            --digest)        digest="$2";        shift 2 ;;
            --target-tag)    target_tag="$2";    shift 2 ;;
            --extra-tags)    extra_tags="$2";    shift 2 ;;
            --name)          name="$2";          shift 2 ;;
            --resolved)      resolved="$2";      shift 2 ;;
            --recipe-digest) recipe_digest="$2"; shift 2 ;;
            --result)        result="$2";        shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$image" ]         || die "--image is required"
    [ -n "$digest" ]        || die "--digest is required"
    [ -n "$target_tag" ]    || die "--target-tag is required"
    [ -n "$extra_tags" ]    || die "--extra-tags is required"
    [ -n "$name" ]          || die "--name is required"
    [ -n "$resolved" ]      || die "--resolved is required"
    [ -n "$recipe_digest" ] || die "--recipe-digest is required"
    [ -n "$result" ]        || die "--result is required"
    [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] \
        || die "--digest must be sha256:<64 hex>: $digest"

    require_cmd jq docker
    jq -e 'type == "array" and all(.[]; type == "string")' <<<"$extra_tags" >/dev/null 2>&1 \
        || die "--extra-tags must be a JSON array of strings: $extra_tags"
    local tags=()
    mapfile -t tags < <(jq -r '.[]' <<<"$extra_tags")

    local args=(buildx imagetools create -t "$image:$target_tag")
    local tag
    for tag in "${tags[@]}"; do
        args+=(-t "$image:$tag")
    done
    args+=("$image@$digest")
    docker "${args[@]}" >&2

    bash "$SCRIPT_DIR/emit-result.sh" --name "$name" --image "$image" \
        --built-tag "$target_tag" --resolved "$resolved" \
        --recipe-digest "$recipe_digest" > "$result"
}

main "$@"