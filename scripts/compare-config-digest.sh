#!/usr/bin/env bash
# compare-config-digest.sh — the config gate (spec 9.1). Prints config=match when
# the marker's configDigest is the SHA-256 of the job.yaml's raw bytes, else
# config=mismatch, for the workflow to redirect into $GITHUB_OUTPUT. Exits 0 for
# both: a mismatch is a green skip.
#
# Usage:
#   compare-config-digest.sh --marker <desired/name.json> --job-yaml <jobs/name/job.yaml>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local marker="" job_yaml=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --marker)   marker="$2";   shift 2 ;;
            --job-yaml) job_yaml="$2"; shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$marker" ]   || die "--marker is required"
    [ -n "$job_yaml" ] || die "--job-yaml is required"
    [ -f "$job_yaml" ] || die "job.yaml not found: $job_yaml"
    require_cmd sha256sum

    local plan line want=""
    plan="$(bash "$SCRIPT_DIR/read-plan.sh" --marker "$marker")" \
        || die "cannot read the plan in $marker"
    while IFS= read -r line; do
        case "$line" in configDigest=*) want="${line#configDigest=}" ;; esac
    done <<<"$plan"

    local hex have
    read -r hex _ < <(sha256sum -- "$job_yaml")
    have="sha256:$hex"

    if [ "$have" = "$want" ]; then
        printf 'config=match\n'
    else
        log "mismatch: $marker was resolved from $want, $job_yaml is now $have"
        printf 'config=mismatch\n'
    fi
}

main "$@"
