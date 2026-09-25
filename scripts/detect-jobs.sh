#!/usr/bin/env bash
# detect-jobs.sh — decide which jobs the GitHub build matrix should run
# (decision 11). Prints jobs=<compact JSON array of job ids> on stdout, for the
# workflow to redirect into $GITHUB_OUTPUT; all logging goes to stderr.
#
# Rules:
#   workflow_dispatch, named job   -> just that job (explicit override)
#   workflow_dispatch, empty job   -> all enabled jobs
#   push, first run                -> all enabled jobs; a first run is an empty
#                                     or all-zeros --before, or one the clone
#                                     does not have (a force-push)
#   push, otherwise                -> enabled jobs whose jobs/<id>/** or
#                                     desired/<id>.json changed between --before
#                                     and --sha; shared-file edits (scripts/**,
#                                     .github/**, …) rebuild nothing
#
# Usage:
#   detect-jobs.sh --event <push|workflow_dispatch> --repo-root <dir>
#                  [--dispatch-job <name>] [--before <sha>] [--sha <sha>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

ZERO_SHA="0000000000000000000000000000000000000000"

# Print each enabled job id (one per line). Enabled unless job.yaml sets
# `enabled: false`. Job id is the directory name (the key for jobs/<id>/ and
# desired/<id>.json alike).
enabled_jobs() {
    local root="$1" dir id
    shopt -s nullglob
    for dir in "$root"/jobs/*/; do
        [ -f "$dir/job.yaml" ] || continue
        id="$(basename "$dir")"
        [ "$(yq -r '.enabled' "$dir/job.yaml")" = "false" ] && continue
        printf '%s\n' "$id"
    done
}

# Emit a sorted, unique, compact JSON array from stdin (one id per line).
to_json_array() { jq -R . | jq -sc 'unique'; }

# True when there is no usable base to diff from.
is_first_run() {
    local root="$1" before="$2"
    [ -z "$before" ] || [ "$before" = "$ZERO_SHA" ] \
        || ! git -C "$root" rev-parse -q --verify "$before^{commit}" >/dev/null 2>&1
}

select_jobs() {
    local event="$1" root="$2" dispatch_job="$3" before="$4" sha="$5"
    case "$event" in
        workflow_dispatch)
            if [ -n "$dispatch_job" ]; then
                [ -f "$root/jobs/$dispatch_job/job.yaml" ] \
                    || die "dispatched job not found: $dispatch_job"
                log "dispatch: building single job $dispatch_job"
                printf '%s\n' "$dispatch_job"
            else
                log "dispatch: building all enabled jobs"
                enabled_jobs "$root"
            fi
            ;;
        push)
            [ -n "$sha" ] || die "--sha is required for a push"
            if is_first_run "$root" "$before"; then
                log "push: first run — building all enabled jobs"
                enabled_jobs "$root"
                return 0
            fi
            local changed enabled affected
            changed="$(git -C "$root" diff --name-only "$before" "$sha")" \
                || die "cannot diff $before..$sha"
            enabled="$(enabled_jobs "$root" | sort -u)"
            affected="$(sed -n -E -e 's#^jobs/([^/]+)/.*#\1#p' \
                -e 's#^desired/([^/]+)\.json$#\1#p' <<<"$changed" | sort -u)"
            log "push: affected=$(printf '%s' "$affected" | tr '\n' ' ')"
            if [ -n "$affected" ] && [ -n "$enabled" ]; then
                comm -12 <(printf '%s\n' "$enabled") <(printf '%s\n' "$affected")
            fi
            ;;
        *)
            die "unknown event: $event"
            ;;
    esac
}

main() {
    local event="" root="" dispatch_job="" before="" sha=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --event)        event="$2";        shift 2 ;;
            --repo-root)    root="$2";         shift 2 ;;
            --dispatch-job) dispatch_job="$2"; shift 2 ;;
            --before)       before="$2";       shift 2 ;;
            --sha)          sha="$2";          shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$event" ] || die "--event is required"
    [ -n "$root" ]  || die "--repo-root is required"
    [ -d "$root" ]  || die "repo root not found: $root"
    require_cmd yq jq git

    # Captured first: a failure inside printf's argument would not stop the script.
    local ids jobs
    ids="$(select_jobs "$event" "$root" "$dispatch_job" "$before" "$sha")"
    jobs="$(printf '%s' "$ids" | sed '/^$/d' | to_json_array)"
    printf 'jobs=%s\n' "$jobs"
}

main "$@"
