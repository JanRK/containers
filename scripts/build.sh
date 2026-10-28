#!/usr/bin/env bash
# build.sh — docker buildx a local- or remote-dockerfile job from plan values.
# Executes the resolved plan verbatim — no substitution (decision 9). All
# placeholders are already resolved into the build args by the
# Forgejo check.
#
# Usage:
#   build.sh --image <registry/name> --build-args '<json object>' --platforms <list>
#            --dockerfile <path> --context <path>
#            [--repo <git-url> --ref <ref>] [--source <repo-url>]
#
# --dockerfile and --context are used as given. With --repo (remote-dockerfile
# mode) the script clones a PUBLIC repo at --ref, and both are relative to the
# clone root — the one path the build plane joins (ADR-0009).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

cleanup_paths=()
cleanup() {
    local path
    for path in "${cleanup_paths[@]}"; do
        rm -rf -- "$path"
    done
}
trap cleanup EXIT

main() {
    local image="" build_args="" platforms=""
    local dockerfile="" context="" repo="" ref="" source=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --image)      image="$2";      shift 2 ;;
            --build-args) build_args="$2"; shift 2 ;;
            --platforms)  platforms="$2";  shift 2 ;;
            --dockerfile) dockerfile="$2"; shift 2 ;;
            --context)    context="$2";    shift 2 ;;
            --repo)       repo="$2";       shift 2 ;;
            --ref)        ref="$2";        shift 2 ;;
            --source)     source="$2";     shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$image" ]      || die "--image is required"
    [ -n "$build_args" ] || die "--build-args is required"
    [ -n "$platforms" ]  || die "--platforms is required"
    [ -n "$dockerfile" ] || die "--dockerfile is required"
    [ -n "$context" ]    || die "--context is required"
    if [ -n "$repo" ]; then
        [ -n "$ref" ] || die "--ref is required with --repo"
    fi
    require_cmd jq docker

    local kvs=()
    jq -e 'type == "object" and all(.[]; type == "string")' <<<"$build_args" >/dev/null 2>&1 \
        || die "--build-args must be a JSON object of strings: $build_args"
    # NUL-delimited: a newline inside a value must not become a second --build-arg.
    mapfile -d '' -t kvs < <(jq -j 'to_entries[] | "\(.key)=\(.value)\u0000"' <<<"$build_args")

    # remote-dockerfile mode: clone a PUBLIC repo at the resolved ref. Private
    # sources are unsupported — GitHub-hosted runners cannot reach them (plan.md
    # decision 1).
    if [ -n "$repo" ]; then
        require_cmd git
        local clone_dir
        clone_dir="$(mktemp -d)"
        cleanup_paths+=("$clone_dir")
        log "clone $repo@$ref"
        git clone --depth 1 --branch "$ref" "$repo" "$clone_dir" >&2 2>/dev/null \
            || { git clone "$repo" "$clone_dir" >&2 && git -C "$clone_dir" checkout "$ref" >&2; } \
            || die "cannot clone $repo at $ref"
        dockerfile="$clone_dir/$dockerfile"
        context="$clone_dir/$context"
    fi
    [ -d "$context" ] || die "context not found: $context"

    # Assemble the buildx argv incrementally so empty collections add nothing.
    local metadata_file
    metadata_file="$(mktemp)"
    cleanup_paths+=("$metadata_file")
    local args=(buildx build --platform "$platforms" -f "$dockerfile")

    # Link the published package to its GitHub repo WITHOUT editing the
    # Dockerfile — works for local-dockerfile and remote-dockerfile jobs alike,
    # including Dockerfiles we do not own. org.opencontainers.image.source is
    # set as a config label and as an image index annotation for GHCR linkage.
    if [ -n "$source" ]; then
        args+=(--label "org.opencontainers.image.source=$source")
        args+=(--annotation "index:org.opencontainers.image.source=$source")
    fi

    local kv
    for kv in "${kvs[@]}"; do
        args+=(--build-arg "$kv")
    done

    args+=(--output "type=image,name=$image,push-by-digest=true,name-canonical=true,push=true")
    args+=(--metadata-file "$metadata_file")
    args+=("$context")

    log "build $image ($platforms)"
    docker "${args[@]}" >&2

    local digest=""
    digest="$(jq -er '."containerimage.digest"' "$metadata_file" 2>/dev/null)" || digest=""
    [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] \
        || die "buildx reported no image digest: $digest"
    printf 'digest=%s\n' "$digest"
}

main "$@"
