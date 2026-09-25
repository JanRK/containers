#!/usr/bin/env bats
# build.sh — docker buildx a local- or remote-dockerfile job from plan values.

load helpers

setupContext() {
    mkdir -p "$TEST_TMP/jobs/multica-agent"
    : > "$TEST_TMP/jobs/multica-agent/Dockerfile"
    CTX="$TEST_TMP/jobs/multica-agent"
}

# A local-dockerfile invocation, with any extra flags appended.
build_local() {
    setupContext
    run --separate-stderr bash "$SCRIPTS_DIR/build.sh" --image ghcr.io/janrk/multica-agent \
        --target-tag m1.2.3-o0.5.0 --extra-tags '["latest"]' \
        --build-args '{"MULTICA_VERSION":"1.2.3","OPENCODE_VERSION":"0.5.0"}' \
        --platforms linux/amd64,linux/arm64 \
        --context "$CTX" --dockerfile "$CTX/Dockerfile" "$@"
}

@test "builds with platforms, dockerfile, build-args, all tags and push" {
    build_local
    [ "$status" -eq 0 ]
    log_has "buildx build"
    log_has "--platform linux/amd64,linux/arm64"
    log_has "--build-arg MULTICA_VERSION=1.2.3"
    log_has "--build-arg OPENCODE_VERSION=0.5.0"
    log_has "-t ghcr.io/janrk/multica-agent:m1.2.3-o0.5.0"
    log_has "-t ghcr.io/janrk/multica-agent:latest"
    log_has "--push"
}

@test "local: uses the dockerfile and context paths verbatim, joining nothing" {
    build_local
    [ "$status" -eq 0 ]
    log_has "-f $CTX/Dockerfile "
    ! log_has "$CTX/$CTX"
    [[ "$(cat "$CALL_LOG")" == *" $CTX" ]]
}

@test "passes no --pull: the resolved tag is immutable and runners are ephemeral" {
    build_local
    [ "$status" -eq 0 ]
    ! log_has "--pull"
}

@test "fails without platforms, rather than defaulting them" {
    setupContext
    run --separate-stderr bash "$SCRIPTS_DIR/build.sh" --image ghcr.io/janrk/x \
        --target-tag 1.0 --extra-tags '[]' --build-args '{}' \
        --context "$CTX" --dockerfile "$CTX/Dockerfile"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--platforms is required"* ]]
    ! log_has "buildx"
}

@test "fails without a dockerfile, rather than defaulting one" {
    setupContext
    run --separate-stderr bash "$SCRIPTS_DIR/build.sh" --image ghcr.io/janrk/x \
        --target-tag 1.0 --extra-tags '[]' --build-args '{}' --platforms linux/amd64 \
        --context "$CTX"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--dockerfile is required"* ]]
    ! log_has "buildx"
}

@test "builds a job with no build-args and no extra tags" {
    setupContext
    run --separate-stderr bash "$SCRIPTS_DIR/build.sh" --image ghcr.io/janrk/x \
        --target-tag 1.0 --extra-tags '[]' --build-args '{}' --platforms linux/amd64 \
        --context "$CTX" --dockerfile "$CTX/Dockerfile"
    [ "$status" -eq 0 ]
    log_has "-t ghcr.io/janrk/x:1.0"
    [ "$(grep -o -- ' -t ' "$CALL_LOG" | wc -l)" -eq 1 ]
    ! log_has "--build-arg"
}

@test "refuses build-args that are not a JSON object of strings, before building" {
    build_local --build-args '["MULTICA_VERSION=1.2.3"]'
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--build-args"* ]]
    ! log_has "buildx"
}

@test "refuses extra tags that are not a JSON array of strings, before building" {
    build_local --extra-tags 'latest'
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--extra-tags"* ]]
    ! log_has "buildx"
}

@test "writes a result artifact" {
    export FAKE_SKOPEO_DIGEST="sha256:2222222222222222222222222222222222222222222222222222222222222222"
    build_local --name multica-agent --resolved '{"multica":"1.2.3"}' --result "$TEST_TMP/result.json"
    [ "$status" -eq 0 ]
    local r="$TEST_TMP/result.json"
    [ "$(jq -r '.name' "$r")" = "multica-agent" ]
    [ "$(jq -r '.builtTag' "$r")" = "m1.2.3-o0.5.0" ]
    [ "$(jq -r '.builtDigest' "$r")" = "sha256:2222222222222222222222222222222222222222222222222222222222222222" ]
    [ "$(jq -r '.resolved.multica' "$r")" = "1.2.3" ]
}

@test "a result needs the name and resolved values it is written from" {
    build_local --result "$TEST_TMP/result.json"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--name"* ]]
    ! log_has "buildx"
}

@test "takes no --plan: the marker is the reader's alone" {
    printf '{}' > "$TEST_TMP/plan.json"
    build_local --plan "$TEST_TMP/plan.json"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"unknown argument: --plan"* ]]
    ! log_has "buildx"
}

@test "skips the push when --push false" {
    build_local --push false
    [ "$status" -eq 0 ]
    ! log_has "--push"
}

@test "links the package to its repo when --source is given" {
    build_local --source https://github.com/JanRK/containers
    [ "$status" -eq 0 ]
    log_has "--label org.opencontainers.image.source=https://github.com/JanRK/containers"
    log_has "--annotation index:org.opencontainers.image.source=https://github.com/JanRK/containers"
}

@test "omits the source label and annotation when --source is absent" {
    build_local
    [ "$status" -eq 0 ]
    ! log_has "org.opencontainers.image.source"
}

@test "keeps the source label but drops the index annotation when not pushing" {
    build_local --push false --source https://github.com/JanRK/containers
    [ "$status" -eq 0 ]
    log_has "--label org.opencontainers.image.source=https://github.com/JanRK/containers"
    ! log_has "--annotation"
}

@test "propagates a docker build failure" {
    export FAKE_DOCKER_FAIL_ON="buildx"
    build_local
    [ "$status" -ne 0 ]
}

# A remote-dockerfile invocation: dockerfile and context are clone-root fragments.
build_remote() {
    run --separate-stderr bash "$SCRIPTS_DIR/build.sh" --image ghcr.io/janrk/paperclip \
        --target-tag v2.5.0 --extra-tags '["latest"]' --build-args '{"APP_VERSION":"2.5.0"}' \
        --platforms linux/amd64 --repo https://github.com/owner/paperclip "$@"
}

@test "clones a public repo at the ref and builds its Dockerfile (remote-dockerfile)" {
    build_remote --ref v2.5.0 --context . --dockerfile Dockerfile \
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

@test "remote: dockerfile and context both join the clone root, and nothing else" {
    export FAKE_GIT_MKDIR=src
    build_remote --ref v2.5.0 --context src --dockerfile docker/Dockerfile
    [ "$status" -eq 0 ]
    grep -qE -- '-f (/[^ ]+)/docker/Dockerfile .* \1/src$' "$CALL_LOG" \
        || { cat "$CALL_LOG"; return 1; }
}

@test "requires --ref when --repo is given" {
    build_remote --context . --dockerfile Dockerfile
    [ "$status" -ne 0 ]
    ! log_has "buildx build"
}

@test "falls back to full clone + checkout when the shallow branch clone fails" {
    export FAKE_GIT_FAIL_ON="--depth 1"
    build_remote --ref deadbeef --context . --dockerfile Dockerfile
    [ "$status" -eq 0 ]
    log_has "checkout deadbeef"
    log_has "buildx build"
}

@test "dies rather than build an empty clone when both clones fail" {
    export FAKE_GIT_FAIL_ON="github.com/owner/paperclip"
    build_remote --ref v2.5.0 --context . --dockerfile Dockerfile
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"cannot clone https://github.com/owner/paperclip at v2.5.0"* ]]
    ! log_has "buildx build"
}
