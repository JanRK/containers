#!/usr/bin/env bats
# mirror.sh — skopeo-copy a resolved source to the target, version or digest.

load helpers

@test "version-pinned: copies source to the target tag" {
    jq -n '{name:"nginx", targetTag:"1.28.0", extraTags:[], source:"docker.io/library/nginx:1.28.0", resolved:{version:"1.28.0"}}' \
        > "$TEST_TMP/plan.json"
    run bash "$SCRIPTS_DIR/mirror.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/nginx
    [ "$status" -eq 0 ]
    log_has "copy --all --retry-times 3 docker://docker.io/library/nginx:1.28.0 docker://ghcr.io/janrk/nginx:1.28.0"
}

@test "version-pinned: applies extra tags from the pushed target" {
    jq -n '{name:"nginx", targetTag:"1.28.0", extraTags:["latest","stable"], source:"docker.io/library/nginx:1.28.0", resolved:{version:"1.28.0"}}' \
        > "$TEST_TMP/plan.json"
    run bash "$SCRIPTS_DIR/mirror.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/nginx
    [ "$status" -eq 0 ]
    log_has "copy --all --retry-times 3 docker://ghcr.io/janrk/nginx:1.28.0 docker://ghcr.io/janrk/nginx:latest"
    log_has "copy --all --retry-times 3 docker://ghcr.io/janrk/nginx:1.28.0 docker://ghcr.io/janrk/nginx:stable"
}

@test "digest-tracked: copies the digest-pinned source ref" {
    jq -n '{name:"searxng", targetTag:"latest", extraTags:[], source:"ghcr.io/searxng/searxng:latest", digest:"sha256:ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc", resolved:{version:"latest"}}' \
        > "$TEST_TMP/plan.json"
    run bash "$SCRIPTS_DIR/mirror.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/searxng
    [ "$status" -eq 0 ]
    log_has "copy --all --retry-times 3 docker://ghcr.io/searxng/searxng@sha256:ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc docker://ghcr.io/janrk/searxng:latest"
}

@test "writes a result artifact with builtTag, builtDigest and resolved" {
    export FAKE_SKOPEO_DIGEST="sha256:1111111111111111111111111111111111111111111111111111111111111111"
    jq -n '{name:"nginx", targetTag:"1.28.0", extraTags:[], source:"docker.io/library/nginx:1.28.0", resolved:{version:"1.28.0"}}' \
        > "$TEST_TMP/plan.json"
    run bash "$SCRIPTS_DIR/mirror.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/nginx --result "$TEST_TMP/result.json"
    [ "$status" -eq 0 ]
    local r="$TEST_TMP/result.json"
    [ "$(jq -r '.name' "$r")" = "nginx" ]
    [ "$(jq -r '.builtTag' "$r")" = "1.28.0" ]
    [ "$(jq -r '.builtDigest' "$r")" = "sha256:1111111111111111111111111111111111111111111111111111111111111111" ]
    [ "$(jq -r '.builtAt' "$r")" = "2026-06-20T12:00:00Z" ]
    [ "$(jq -r '.resolved.version' "$r")" = "1.28.0" ]
}

@test "fails when the plan has no source" {
    jq -n '{name:"nginx", targetTag:"1.28.0", extraTags:[]}' > "$TEST_TMP/plan.json"
    run bash "$SCRIPTS_DIR/mirror.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/nginx
    [ "$status" -ne 0 ]
}

@test "propagates a skopeo copy failure" {
    export FAKE_SKOPEO_FAIL_ON="copy"
    jq -n '{name:"nginx", targetTag:"1.28.0", extraTags:[], source:"docker.io/library/nginx:1.28.0", resolved:{}}' \
        > "$TEST_TMP/plan.json"
    run bash "$SCRIPTS_DIR/mirror.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/nginx
    [ "$status" -ne 0 ]
}
