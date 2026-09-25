#!/usr/bin/env bash
# commit-record.sh — commit and push what record.sh wrote, under the given
# author, or skip cleanly when nothing under the paths changed. Commits only
# those paths, and leaves the clone's git config as it found it.
#
# Usage:
#   commit-record.sh --repo-root <dir> --name <author> --email <address>
#                    --message <text> --path <path> [--path <path> ...]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local root="" name="" email="" message="" paths=()
    while [ $# -gt 0 ]; do
        case "$1" in
            --repo-root) root="$2";    shift 2 ;;
            --name)      name="$2";    shift 2 ;;
            --email)     email="$2";   shift 2 ;;
            --message)   message="$2"; shift 2 ;;
            --path)      paths+=("$2"); shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$root" ]         || die "--repo-root is required"
    [ -n "$name" ]         || die "--name is required"
    [ -n "$email" ]        || die "--email is required"
    [ -n "$message" ]      || die "--message is required"
    [ "${#paths[@]}" -gt 0 ] || die "--path is required"
    [ -d "$root" ]         || die "repo root not found: $root"
    require_cmd git

    local changes
    changes="$(git -C "$root" status --porcelain -- "${paths[@]}")"
    if [ -z "$changes" ]; then
        log "nothing to commit under ${paths[*]}"
        return 0
    fi

    # git refuses a pathspec that matches nothing, and record.sh may not have written every path.
    local p present=()
    for p in "${paths[@]}"; do
        [ ! -e "$root/$p" ] || present+=("$p")
    done
    git -C "$root" add -- "${present[@]}"
    git -C "$root" -c user.name="$name" -c user.email="$email" \
        commit -q -m "$message" -- "${present[@]}"
    git -C "$root" push -q
    log "committed and pushed ${paths[*]}"
}

main "$@"
