#!/usr/bin/env bash
# detect-jobs.sh — decide which jobs the GitHub build matrix should run
# (decision 11). Emits a compact JSON array of job ids on stdout; all logging
# goes to stderr so the array can be captured cleanly into a workflow output.
#
# Rules:
#   workflow_dispatch, named job   -> just that job (explicit override)
#   workflow_dispatch, empty job   -> all enabled jobs
#   push, first run / no before-SHA-> all enabled jobs
#   push, otherwise                -> enabled jobs whose jobs/<id>/** or
#                                     desired/<id>.json changed; shared-file
#                                     edits (scripts/**, .github/**, …) rebuild
#                                     nothing
#
# Usage:
#   detect-jobs.sh --event <push|workflow_dispatch> --repo-root <dir>
#                  [--dispatch-job <name>] [--changed-files <path>]
#                  [--first-run <true|false>]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

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

main() {
    local event="" root="" dispatch_job="" changed_files="" first_run="false"
    local dispatch_job_set="false"
    while [ $# -gt 0 ]; do
        case "$1" in
            --event)         event="$2";          shift 2 ;;
            --repo-root)     root="$2";           shift 2 ;;
            --dispatch-job)  dispatch_job="$2"; dispatch_job_set="true"; shift 2 ;;
            --changed-files) changed_files="$2";  shift 2 ;;
            --first-run)     first_run="$2";      shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$event" ] || die "--event is required"
    [ -n "$root" ]  || die "--repo-root is required"
    [ -d "$root" ]  || die "repo root not found: $root"
    require_cmd yq jq

    case "$event" in
        workflow_dispatch)
            if [ "$dispatch_job_set" = "true" ] && [ -n "$dispatch_job" ]; then
                [ -f "$root/jobs/$dispatch_job/job.yaml" ] \
                    || die "dispatched job not found: $dispatch_job"
                log "dispatch: building single job $dispatch_job"
                printf '%s\n' "$dispatch_job" | to_json_array
            else
                log "dispatch: building all enabled jobs"
                enabled_jobs "$root" | to_json_array
            fi
            ;;
        push)
            if [ "$first_run" = "true" ]; then
                log "push: first run — building all enabled jobs"
                enabled_jobs "$root" | to_json_array
                return 0
            fi
            # Map changed paths to affected job ids, then keep only enabled ones.
            local enabled affected
            enabled="$(enabled_jobs "$root" | sort -u)"
            affected=""
            if [ -n "$changed_files" ] && [ -f "$changed_files" ]; then
                affected="$( {
                    sed -n -E 's#^jobs/([^/]+)/.*#\1#p'    "$changed_files"
                    sed -n -E 's#^desired/([^/]+)\.json$#\1#p' "$changed_files"
                } | sort -u )"
            fi
            log "push: affected=$(printf '%s' "$affected" | tr '\n' ' ')"
            # Intersection of affected and enabled.
            if [ -n "$affected" ] && [ -n "$enabled" ]; then
                comm -12 \
                    <(printf '%s\n' "$enabled") \
                    <(printf '%s\n' "$affected") | to_json_array
            else
                printf '[]\n'
            fi
            ;;
        *)
            die "unknown event: $event"
            ;;
    esac
}

main "$@"
