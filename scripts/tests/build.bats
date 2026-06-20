#!/usr/bin/env bats
# build.sh — docker buildx a local-dockerfile job from the resolved plan.

load helpers

writePlan() {
    jq -n '{name:"multica-agent", targetTag:"m1.2.3-o0.5.0", extraTags:["latest"],
            buildArgs:{MULTICA_VERSION:"1.2.3", OPENCODE_VERSION:"0.5.0"}, resolved:{multica:"1.2.3"}}' \
        > "$TEST_TMP/plan.json"
    mkdir -p "$TEST_TMP/ctx"
    : > "$TEST_TMP/ctx/Dockerfile"
}

@test "builds with platforms, dockerfile, build-args, all tags and push" {
    writePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx" --platforms linux/amd64,linux/arm64
    [ "$status" -eq 0 ]
    log_has "buildx build"
    log_has "--platform linux/amd64,linux/arm64"
    log_has "-f $TEST_TMP/ctx/Dockerfile"
    log_has "--build-arg MULTICA_VERSION=1.2.3"
    log_has "--build-arg OPENCODE_VERSION=0.5.0"
    log_has "-t ghcr.io/janrk/multica-agent:m1.2.3-o0.5.0"
    log_has "-t ghcr.io/janrk/multica-agent:latest"
    log_has "--push"
}

@test "defaults the platforms when not supplied" {
    writePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx"
    [ "$status" -eq 0 ]
    log_has "--platform linux/amd64,linux/arm64"
}

@test "uses a custom dockerfile name" {
    writePlan
    mv "$TEST_TMP/ctx/Dockerfile" "$TEST_TMP/ctx/Dockerfile.alpine"
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx" --dockerfile Dockerfile.alpine
    [ "$status" -eq 0 ]
    log_has "-f $TEST_TMP/ctx/Dockerfile.alpine"
}

@test "builds a job with no build-args" {
    jq -n '{name:"x", targetTag:"1.0", extraTags:[], buildArgs:{}, resolved:{}}' > "$TEST_TMP/plan.json"
    mkdir -p "$TEST_TMP/ctx"; : > "$TEST_TMP/ctx/Dockerfile"
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/x \
        --context "$TEST_TMP/ctx"
    [ "$status" -eq 0 ]
    log_has "-t ghcr.io/janrk/x:1.0"
    ! log_has "--build-arg"
}

@test "writes a result artifact" {
    export FAKE_SKOPEO_DIGEST="sha256:2222222222222222222222222222222222222222222222222222222222222222"
    writePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx" --result "$TEST_TMP/result.json"
    [ "$status" -eq 0 ]
    local r="$TEST_TMP/result.json"
    [ "$(jq -r '.name' "$r")" = "multica-agent" ]
    [ "$(jq -r '.builtTag' "$r")" = "m1.2.3-o0.5.0" ]
    [ "$(jq -r '.builtDigest' "$r")" = "sha256:2222222222222222222222222222222222222222222222222222222222222222" ]
    [ "$(jq -r '.resolved.multica' "$r")" = "1.2.3" ]
}

@test "skips the push when --push false" {
    writePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx" --push false
    [ "$status" -eq 0 ]
    ! log_has "--push"
}

@test "propagates a docker build failure" {
    export FAKE_DOCKER_FAIL_ON="buildx"
    writePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx"
    [ "$status" -ne 0 ]
}
