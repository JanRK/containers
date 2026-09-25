#!/usr/bin/env bash
# build.sh — docker buildx a local- or remote-dockerfile job from plan values.
# Executes the resolved plan verbatim — no substitution (decision 9). All
# placeholders are already resolved into the build args and tags by the
# Forgejo check.
#
# Usage:
#   build.sh --image <registry/name> --target-tag <tag> --extra-tags '<json array>'
#            --build-args '<json object>' --platforms <list>
#            --dockerfile <path> --context <path>
#            [--repo <git-url> --ref <ref>] [--push <true|false>] [--source <repo-url>]
#            [--result <path> --name <job> --resolved '<json object>']
#
# --dockerfile and --context are used as given. With --repo (remote-dockerfile
# mode) the script clones a PUBLIC repo at --ref, and both are relative to the
# clone root — the one path the build plane joins (ADR-0009).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib.sh
. "$SCRIPT_DIR/lib.sh"

main() {
    local image="" target_tag="" extra_tags="" build_args="" platforms=""
    local dockerfile="" context="" repo="" ref="" push="true" source=""
    local result="" name="" resolved=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --image)      image="$2";      shift 2 ;;
            --target-tag) target_tag="$2"; shift 2 ;;
            --extra-tags) extra_tags="$2"; shift 2 ;;
            --build-args) build_args="$2"; shift 2 ;;
            --platforms)  platforms="$2";  shift 2 ;;
            --dockerfile) dockerfile="$2"; shift 2 ;;
            --context)    context="$2";    shift 2 ;;
            --repo)       repo="$2";       shift 2 ;;
            --ref)        ref="$2";        shift 2 ;;
            --push)       push="$2";       shift 2 ;;
            --source)     source="$2";     shift 2 ;;
            --result)     result="$2";     shift 2 ;;
            --name)       name="$2";       shift 2 ;;
            --resolved)   resolved="$2";   shift 2 ;;
            *) die "unknown argument: $1" ;;
        esac
    done
    [ -n "$image" ]      || die "--image is required"
    [ -n "$target_tag" ] || die "--target-tag is required"
    [ -n "$extra_tags" ] || die "--extra-tags is required"
    [ -n "$build_args" ] || die "--build-args is required"
    [ -n "$platforms" ]  || die "--platforms is required"
    [ -n "$dockerfile" ] || die "--dockerfile is required"
    [ -n "$context" ]    || die "--context is required"
    if [ -n "$repo" ]; then
        [ -n "$ref" ] || die "--ref is required with --repo"
    fi
    if [ -n "$result" ]; then
        [ -n "$name" ]     || die "--name is required with --result"
        [ -n "$resolved" ] || die "--resolved is required with --result"
    fi
    require_cmd jq docker

    local tags=() kvs=()
    jq -e 'type == "array" and all(.[]; type == "string")' <<<"$extra_tags" >/dev/null 2>&1 \
        || die "--extra-tags must be a JSON array of strings: $extra_tags"
    jq -e 'type == "object" and all(.[]; type == "string")' <<<"$build_args" >/dev/null 2>&1 \
        || die "--build-args must be a JSON object of strings: $build_args"
    mapfile -t tags < <(jq -r '.[]' <<<"$extra_tags")
    # NUL-delimited: a newline inside a value must not become a second --build-arg.
    mapfile -d '' -t kvs < <(jq -j 'to_entries[] | "\(.key)=\(.value)\u0000"' <<<"$build_args")

    # remote-dockerfile mode: clone a PUBLIC repo at the resolved ref. Private
    # sources are unsupported — GitHub-hosted runners cannot reach them (plan.md
    # decision 1).
    if [ -n "$repo" ]; then
        require_cmd git
        local clone_dir
        clone_dir="$(mktemp -d)"
        # shellcheck disable=SC2064
        trap "rm -rf '$clone_dir'" EXIT
        log "clone $repo@$ref"
        git clone --depth 1 --branch "$ref" "$repo" "$clone_dir" 2>/dev/null \
            || { git clone "$repo" "$clone_dir" && git -C "$clone_dir" checkout "$ref"; } \
            || die "cannot clone $repo at $ref"
        dockerfile="$clone_dir/$dockerfile"
        context="$clone_dir/$context"
    fi
    [ -d "$context" ] || die "context not found: $context"

    # Assemble the buildx argv incrementally so empty collections add nothing.
    local args=(buildx build --platform "$platforms" -f "$dockerfile")

    # Link the published package to its GitHub repo WITHOUT editing the
    # Dockerfile — works for local-dockerfile and remote-dockerfile jobs alike,
    # including Dockerfiles we do not own. org.opencontainers.image.source is
    # set as a config label (the GitHub-documented build-time alternative to a
    # Dockerfile LABEL) and, for the pushed multi-arch manifest, as an image
    # index annotation (GHCR reads the index for multi-arch repo linkage).
    if [ -n "$source" ]; then
        args+=(--label "org.opencontainers.image.source=$source")
        [ "$push" = "true" ] \
            && args+=(--annotation "index:org.opencontainers.image.source=$source")
    fi

    local kv t
    for kv in "${kvs[@]}"; do
        args+=(--build-arg "$kv")
    done

    args+=(-t "$image:$target_tag")
    for t in "${tags[@]}"; do
        args+=(-t "$image:$t")
    done

    [ "$push" = "true" ] && args+=(--push)
    args+=("$context")

    log "build $image:$target_tag ($platforms)"
    docker "${args[@]}"

    if [ -n "$result" ]; then
        bash "$SCRIPT_DIR/emit-result.sh" --name "$name" --image "$image" \
            --built-tag "$target_tag" --resolved "$resolved" > "$result"
        log "wrote result artifact $result"
    fi
    return 0
}

main "$@"
