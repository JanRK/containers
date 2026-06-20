#!/usr/bin/env bash
# record.sh — fold build/mirror result artifacts into state receipts and
# capped per-job history. SOLE writer of state/ and history/ on the GitHub side.
#
# Usage:
#   record.sh --artifacts <dir> --state-dir <dir> --history-dir <dir> [--history-cap <n>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local artifacts="" state_dir="" history_dir="" cap=30
    while [ $# -gt 0 ]; do
        case "$1" in
            --artifacts)   artifacts="$2"; shift 2 ;;
            --state-dir)   state_dir="$2"; shift 2 ;;
            --history-dir) history_dir="$2"; shift 2 ;;
            --history-cap) cap="$2"; shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$artifacts" ]   || die "--artifacts is required"
    [ -n "$state_dir" ]   || die "--state-dir is required"
    [ -n "$history_dir" ] || die "--history-dir is required"
    [ -d "$artifacts" ]   || die "artifacts directory not found: $artifacts"

    require_cmd jq
    mkdir -p "$state_dir" "$history_dir"

    shopt -s nullglob
    local f processed=0
    for f in "$artifacts"/*.json; do
        record_one "$f" "$state_dir" "$history_dir" "$cap"
        processed=$((processed + 1))
    done
    log "recorded $processed artifact(s)"
}

record_one() {
    local f="$1" state_dir="$2" history_dir="$3" cap="$4"

    # Required fields — split declaration from assignment so `set -e`/`||`
    # see jq's exit status rather than `local`'s (which is always 0).
    local name built_tag built_digest
    name="$(jq -er '.name' "$f")"                 || die "artifact $f missing .name"
    built_tag="$(jq -er '.builtTag' "$f")"        || die "artifact $f missing .builtTag"
    built_digest="$(jq -er '.builtDigest' "$f")"  || die "artifact $f missing .builtDigest"
    jq -e '.builtAt' "$f" >/dev/null              || die "artifact $f missing .builtAt"

    # state receipt: only the receipt fields, sorted for stable diffs.
    jq -S '{name, builtTag, builtDigest, builtAt}' "$f" > "$state_dir/$name.json"

    # history: prepend newest-first, cap to N.
    local hist="$history_dir/$name.json" existing="[]"
    [ -f "$hist" ] && existing="$(cat "$hist")"
    jq --argjson cap "$cap" --argjson prev "$existing" \
        '[{builtTag, resolved, builtDigest, builtAt}] + $prev | .[0:$cap]' \
        "$f" > "$hist"

    log "recorded $name -> $built_tag ($built_digest)"
}

main "$@"
