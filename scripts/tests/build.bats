#!/usr/bin/env bats
# build.sh — docker buildx pushes an image by digest for a later smoke test.

load helpers

setupContext() {
    mkdir -p "$TEST_TMP/jobs/multica-agent"
    : > "$TEST_TMP/jobs/multica-agent/Dockerfile"
    CTX="$TEST_TMP/jobs/multica-agent"
}

build_local() {
    setupContext
    run --separate-stderr bash "$SCRIPTS_DIR/build.sh" --image ghcr.io/janrk/multica-agent \
        --build-args '{"MULTICA_VERSION":"1.2.3","OPENCODE_VERSION":"0.5.0"}' \
        --platforms linux/amd64,linux/arm64 \
        --context "$CTX" --dockerfile "$CTX/Dockerfile" "$@"
}

@test "pushes by digest with exact output and metadata-file arguments, without tags" {
    build_local
    [ "$status" -eq 0 ]
    [ "$output" = "digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ]
    log_has "buildx build"
    log_has "--platform linux/amd64,linux/arm64"
    log_has "--build-arg MULTICA_VERSION=1.2.3"
    log_has "--build-arg OPENCODE_VERSION=0.5.0"
    log_has "--output type=image,name=ghcr.io/janrk/multica-agent,push-by-digest=true,name-canonical=true,push=true"
    log_has "--metadata-file "
    ! log_has " -t "
    ! log_has "--push"
}

@test "local: uses the dockerfile and context paths verbatim, joining nothing" {
    build_local
    [ "$status" -eq 0 ]
    log_has "-f $CTX/Dockerfile "
    ! log_has "$CTX/$CTX"
    [[ "$(cat "$CALL_LOG")" == *" $CTX" ]]
}

@test "passes no --pull" {
    build_local
    [ "$status" -eq 0 ]
    ! log_has "--pull"
}

@test "fails without platforms, rather than defaulting them" {
    setupContext
    run --separate-stderr bash "$SCRIPTS_DIR/build.sh" --image ghcr.io/janrk/x \
        --build-args '{}' \
        --context "$CTX" --dockerfile "$CTX/Dockerfile"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--platforms is required"* ]]
    ! log_has "buildx"
}

@test "fails without a dockerfile, rather than defaulting one" {
    setupContext
    run --separate-stderr bash "$SCRIPTS_DIR/build.sh" --image ghcr.io/janrk/x \
        --build-args '{}' --platforms linux/amd64 \
        --context "$CTX"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--dockerfile is required"* ]]
    ! log_has "buildx"
}

@test "refuses build-args that are not a JSON object of strings, before building" {
    build_local --build-args '["MULTICA_VERSION=1.2.3"]'
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--build-args"* ]]
    ! log_has "buildx"
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

@test "propagates a docker build failure" {
    export FAKE_DOCKER_FAIL_ON="buildx"
    build_local
    [ "$status" -ne 0 ]
}

@test "dies when buildx reports no image digest" {
    unset FAKE_BUILDX_DIGEST
    build_local
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"buildx reported no image digest:"* ]]
}

@test "dies when buildx reports a malformed image digest" {
    export FAKE_BUILDX_DIGEST="sha256:BAD"
    build_local
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"buildx reported no image digest: sha256:BAD"* ]]
}

@test "removed arguments die as unknown arguments" {
    local argument
    for argument in --target-tag --extra-tags --push --result --name --resolved; do
        build_local "$argument" ignored
        [ "$status" -ne 0 ]
        [[ "$stderr" == *"unknown argument: $argument"* ]]
        ! log_has "buildx"
    done
}

# A remote-dockerfile invocation: dockerfile and context are clone-root fragments.
build_remote() {
    run --separate-stderr bash "$SCRIPTS_DIR/build.sh" --image ghcr.io/janrk/paperclip \
        --build-args '{"APP_VERSION":"2.5.0"}' \
        --platforms linux/amd64 --repo https://github.com/owner/paperclip "$@"
}

@test "clones a public repo at the ref and builds its Dockerfile (remote-dockerfile)" {
    build_remote --ref v2.5.0 --context . --dockerfile Dockerfile \
        --source https://github.com/owner/paperclip
    [ "$status" -eq 0 ]
    [ "$output" = "digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ]
    log_has "git clone --depth 1 --branch v2.5.0 https://github.com/owner/paperclip"
    log_has "buildx build"
    log_has "--build-arg APP_VERSION=2.5.0"
    log_has "--label org.opencontainers.image.source=https://github.com/owner/paperclip"
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
    [ "$output" = "digest=sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" ]
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
