#!/usr/bin/env bash
# build.sh — docker buildx a local-dockerfile job from its resolved plan.
# Executes the resolved plan verbatim — no substitution (decision 9). All
# placeholders are already resolved into buildArgs/targetTag/extraTags by the
# Forgejo check.
#
# Usage:
#   build.sh --plan <desired.json> --image <registry/name> --context <dir>
#            [--dockerfile <name>] [--platforms <list>] [--push <true|false>]
#            [--result <path>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local plan="" image="" context="" dockerfile="Dockerfile"
    local platforms="linux/amd64,linux/arm64" push="true" result=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --plan)       plan="$2";       shift 2 ;;
            --image)      image="$2";      shift 2 ;;
            --context)    context="$2";    shift 2 ;;
            --dockerfile) dockerfile="$2"; shift 2 ;;
            --platforms)  platforms="$2";  shift 2 ;;
            --push)       push="$2";       shift 2 ;;
            --result)     result="$2";     shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$plan" ]    || die "--plan is required"
    [ -n "$image" ]   || die "--image is required"
    [ -n "$context" ] || die "--context is required"
    [ -f "$plan" ]    || die "plan not found: $plan"
    [ -d "$context" ] || die "context not found: $context"
    require_cmd jq docker

    local target_tag
    target_tag="$(json_req "$plan" '.targetTag' targetTag)"

    # Assemble the buildx argv incrementally so empty collections add nothing.
    local args=(buildx build --platform "$platforms" -f "$context/$dockerfile")

    local kv
    while IFS= read -r kv; do
        [ -n "$kv" ] || continue
        args+=(--build-arg "$kv")
    done < <(jq -r '.buildArgs // {} | to_entries[] | "\(.key)=\(.value)"' "$plan")

    args+=(-t "$image:$target_tag")
    local t
    while IFS= read -r t; do
        [ -n "$t" ] || continue
        args+=(-t "$image:$t")
    done < <(jq -r '.extraTags[]?' "$plan")

    [ "$push" = "true" ] && args+=(--push)
    args+=("$context")

    log "build $image:$target_tag ($platforms)"
    docker "${args[@]}"

    [ -n "$result" ] && emit_result "$plan" "$image" "$target_tag" "$result"
    return 0
}

main "$@"
