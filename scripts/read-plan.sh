#!/usr/bin/env bash
# read-plan.sh — the plan reader, the ONLY script that opens a marker (spec 9.4).
# Prints key=value lines; the workflow redirects them into $GITHUB_OUTPUT.
# platforms prints comma-joined; extraTags, resolved, test, buildArgs as compact JSON.
# Prints nothing unless the whole marker reads.
#
# Usage:
#   read-plan.sh --marker <desired/name.json>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

marker=""
value=""
lines=()

# Read <path> through a jq type filter into $value; die unless it is one non-empty line.
read_field() {
    local path="$1" filter="$2"
    value="$(jq -er "$path | $filter" "$marker" 2>/dev/null)" \
        || die "$marker: $path is missing, null or of the wrong type"
    [ -n "$value" ] || die "$marker: $path is empty"
    [[ "$value" != *[$'\n\r']* ]] || die "$marker: $path spans more than one line"
}

# Queue <last path segment>=<value> for output.
emit() {
    read_field "$1" "$2"
    lines+=("${1##*.}=$value")
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --marker) marker="$2"; shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$marker" ] || die "--marker is required"
    [ -f "$marker" ] || die "marker not found: $marker"
    require_cmd jq

    jq empty "$marker" 2>/dev/null || die "$marker: not valid JSON"
    jq -e '.plan | objects' "$marker" >/dev/null 2>&1 \
        || die "$marker: flat marker, no .plan object — markers nest the plan under .plan"

    emit .plan.name strings
    emit .plan.mode strings
    local mode="$value"
    emit .plan.image strings
    emit .plan.track strings
    local track="$value"
    emit .plan.targetTag strings
    emit .plan.extraTags 'arrays | tojson'
    emit .plan.resolved 'objects | tojson'
    emit .plan.platforms 'arrays | join(",")'
    emit .plan.test 'arrays | tojson'

    case "$mode" in
        mirror)
            emit .plan.mirrorSource strings
            [ "$track" != "digest" ] || emit .plan.digest strings
            ;;
        local-dockerfile)
            emit .plan.buildArgs 'objects | tojson'
            emit .plan.dockerfile strings
            emit .plan.context strings
            ;;
        remote-dockerfile)
            emit .plan.repo strings
            emit .plan.ref strings
            emit .plan.buildArgs 'objects | tojson'
            emit .plan.dockerfile strings
            emit .plan.context strings
            ;;
        *) die "$marker: unknown .plan.mode: $mode" ;;
    esac

    emit .configDigest strings
    emit .desiredAt strings
    emit .firstDesiredAt strings
    emit .attempt numbers

    # Verbatim execution: a leftover placeholder is a resolution bug, never expanded here.
    local unexpanded
    unexpanded="$(jq -r '[.plan
        | (.targetTag, .ref, .mirrorSource, .context, .dockerfile, .extraTags[]?, (.buildArgs // {} | .[]?))
        | strings | select(test("\\{[^}]*\\}"))] | first // empty' "$marker")"
    [ -z "$unexpanded" ] || die "$marker: unexpanded placeholder in '$unexpanded'"

    printf '%s\n' "${lines[@]}"
}

main "$@"
