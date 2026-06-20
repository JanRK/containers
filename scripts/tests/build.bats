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

@test "links the package to its repo when --source is given" {
    writePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx" --source https://github.com/JanRK/containers
    [ "$status" -eq 0 ]
    log_has "--label org.opencontainers.image.source=https://github.com/JanRK/containers"
    log_has "--annotation index:org.opencontainers.image.source=https://github.com/JanRK/containers"
}

@test "omits the source label and annotation when --source is absent" {
    writePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx"
    [ "$status" -eq 0 ]
    ! log_has "org.opencontainers.image.source"
}

@test "keeps the source label but drops the index annotation when not pushing" {
    writePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx" --push false --source https://github.com/JanRK/containers
    [ "$status" -eq 0 ]
    log_has "--label org.opencontainers.image.source=https://github.com/JanRK/containers"
    ! log_has "--annotation"
}

@test "propagates a docker build failure" {
    export FAKE_DOCKER_FAIL_ON="buildx"
    writePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/multica-agent \
        --context "$TEST_TMP/ctx"
    [ "$status" -ne 0 ]
}

writeRemotePlan() {
    jq -n '{name:"paperclip", targetTag:"v2.5.0", extraTags:["latest"],
            buildArgs:{APP_VERSION:"2.5.0"}, resolved:{app:"2.5.0"},
            repo:"https://github.com/owner/paperclip", ref:"v2.5.0",
            dockerfile:"Dockerfile", context:"."}' > "$TEST_TMP/plan.json"
}

@test "clones a public repo at the ref and builds its Dockerfile (remote-dockerfile)" {
    writeRemotePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/paperclip \
        --repo https://github.com/owner/paperclip --ref v2.5.0 \
        --context . --dockerfile Dockerfile \
        --source https://github.com/owner/paperclip
    [ "$status" -eq 0 ]
    log_has "git clone --depth 1 --branch v2.5.0 https://github.com/owner/paperclip"
    log_has "buildx build"
    log_has "-t ghcr.io/janrk/paperclip:v2.5.0"
    log_has "-t ghcr.io/janrk/paperclip:latest"
    log_has "--build-arg APP_VERSION=2.5.0"
    log_has "--label org.opencontainers.image.source=https://github.com/owner/paperclip"
    log_has "--push"
}

@test "requires --ref when --repo is given" {
    writeRemotePlan
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/paperclip \
        --repo https://github.com/owner/paperclip --context .
    [ "$status" -ne 0 ]
    ! log_has "buildx build"
}

@test "falls back to full clone + checkout when the shallow branch clone fails" {
    writeRemotePlan
    export FAKE_GIT_FAIL_ON="--depth 1"
    run bash "$SCRIPTS_DIR/build.sh" --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/paperclip \
        --repo https://github.com/owner/paperclip --ref deadbeef \
        --context . --dockerfile Dockerfile
    [ "$status" -eq 0 ]
    log_has "checkout deadbeef"
    log_has "buildx build"
}
