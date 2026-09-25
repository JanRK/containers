#!/usr/bin/env bats
# mirror.sh — skopeo-copy a resolved source to the target, version or digest.

load helpers

mirror() {
    run --separate-stderr bash "$SCRIPTS_DIR/mirror.sh" "$@"
}

@test "version-pinned: copies source to the target tag" {
    mirror --source docker.io/library/nginx:1.28.0 --image ghcr.io/janrk/nginx \
        --target-tag 1.28.0 --extra-tags '[]'
    [ "$status" -eq 0 ]
    log_has "copy --all --retry-times 3 docker://docker.io/library/nginx:1.28.0 docker://ghcr.io/janrk/nginx:1.28.0"
    [ "$(log_count skopeo)" -eq 1 ]
}

@test "version-pinned: applies extra tags from the pushed target" {
    mirror --source docker.io/library/nginx:1.28.0 --image ghcr.io/janrk/nginx \
        --target-tag 1.28.0 --extra-tags '["latest","stable"]'
    [ "$status" -eq 0 ]
    log_has "copy --all --retry-times 3 docker://ghcr.io/janrk/nginx:1.28.0 docker://ghcr.io/janrk/nginx:latest"
    log_has "copy --all --retry-times 3 docker://ghcr.io/janrk/nginx:1.28.0 docker://ghcr.io/janrk/nginx:stable"
}

@test "digest-tracked: copies the already-pinned source verbatim, joining nothing" {
    local pinned="ghcr.io/searxng/searxng@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    mirror --source "$pinned" --image ghcr.io/janrk/searxng --target-tag latest --extra-tags '[]'
    [ "$status" -eq 0 ]
    log_has "copy --all --retry-times 3 docker://$pinned docker://ghcr.io/janrk/searxng:latest"
}

@test "writes a result artifact with builtTag, builtDigest and resolved" {
    export FAKE_SKOPEO_DIGEST="sha256:1111111111111111111111111111111111111111111111111111111111111111"
    mirror --source docker.io/library/nginx:1.28.0 --image ghcr.io/janrk/nginx \
        --target-tag 1.28.0 --extra-tags '[]' \
        --name nginx --resolved '{"version":"1.28.0"}' --result "$TEST_TMP/result.json"
    [ "$status" -eq 0 ]
    local r="$TEST_TMP/result.json"
    [ "$(jq -r '.name' "$r")" = "nginx" ]
    [ "$(jq -r '.builtTag' "$r")" = "1.28.0" ]
    [ "$(jq -r '.builtDigest' "$r")" = "sha256:1111111111111111111111111111111111111111111111111111111111111111" ]
    [ "$(jq -r '.builtAt' "$r")" = "2026-06-20T12:00:00Z" ]
    [ "$(jq -r '.resolved.version' "$r")" = "1.28.0" ]
}

@test "fails without a source" {
    mirror --image ghcr.io/janrk/nginx --target-tag 1.28.0 --extra-tags '[]'
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--source is required"* ]]
    [ "$(log_count skopeo)" -eq 0 ]
}

@test "fails without extra tags, rather than defaulting them" {
    mirror --source docker.io/library/nginx:1.28.0 --image ghcr.io/janrk/nginx --target-tag 1.28.0
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--extra-tags is required"* ]]
    [ "$(log_count skopeo)" -eq 0 ]
}

@test "refuses extra tags that are not a JSON array of strings, before copying anything" {
    mirror --source docker.io/library/nginx:1.28.0 --image ghcr.io/janrk/nginx \
        --target-tag 1.28.0 --extra-tags 'latest'
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--extra-tags"* ]]
    [ "$(log_count skopeo)" -eq 0 ]
}

@test "a result needs the name and resolved values it is written from" {
    mirror --source docker.io/library/nginx:1.28.0 --image ghcr.io/janrk/nginx \
        --target-tag 1.28.0 --extra-tags '[]' --result "$TEST_TMP/result.json"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--name"* ]]
    [ "$(log_count skopeo)" -eq 0 ]
}

@test "takes no --plan: the marker is the reader's alone" {
    printf '{}' > "$TEST_TMP/plan.json"
    mirror --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/nginx
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"unknown argument: --plan"* ]]
}

@test "propagates a skopeo copy failure" {
    export FAKE_SKOPEO_FAIL_ON="copy"
    mirror --source docker.io/library/nginx:1.28.0 --image ghcr.io/janrk/nginx \
        --target-tag 1.28.0 --extra-tags '[]'
    [ "$status" -ne 0 ]
}
