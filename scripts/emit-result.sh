#!/usr/bin/env bash
# emit-result.sh — print the result artifact for a just-pushed tag (spec 5.4, 9.3).
# Any failure to read the pushed digest back is fatal: an empty builtDigest
# would corrupt the receipt the check plane resolves dependents from.
#
# Usage:
#   emit-result.sh --name <job> --image <registry/name> --built-tag <tag>
#                  --resolved '<json object>'
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

# Current UTC timestamp in the marker format (yyyy-MM-ddTHH:mm:ssZ).
now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

main() {
    local name="" image="" built_tag="" resolved=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --name)      name="$2";      shift 2 ;;
            --image)     image="$2";     shift 2 ;;
            --built-tag) built_tag="$2"; shift 2 ;;
            --resolved)  resolved="$2";  shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$name" ]      || die "--name is required"
    [ -n "$image" ]     || die "--image is required"
    [ -n "$built_tag" ] || die "--built-tag is required"
    [ -n "$resolved" ]  || die "--resolved is required"
    require_cmd jq
    jq -e 'type == "object"' <<<"$resolved" >/dev/null 2>&1 \
        || die "--resolved must be a JSON object: $resolved"

    local observation built_digest
    observation="$(bash "$SCRIPT_DIR/observe-tag.sh" --ref "$image:$built_tag")" \
        || die "cannot read back the digest of $image:$built_tag"
    case "$observation" in
        "present "*) built_digest="${observation#present }" ;;
        absent) die "$image:$built_tag is absent after a successful push" ;;
        *) die "unrecognised observation of $image:$built_tag: $observation" ;;
    esac

    jq -n \
        --arg name "$name" \
        --arg builtTag "$built_tag" \
        --arg builtDigest "$built_digest" \
        --arg builtAt "${BUILT_AT:-$(now_utc)}" \
        --argjson resolved "$resolved" \
        '{name:$name, builtTag:$builtTag, builtDigest:$builtDigest, builtAt:$builtAt, resolved:$resolved}'
}

main "$@"
