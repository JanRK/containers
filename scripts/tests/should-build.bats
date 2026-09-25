#!/usr/bin/env bats
# should-build.sh — registry-skip guard (decision 3). Re-checks the registry and
# prints "build" or "skip" so the build leg can short-circuit cheaply.

load helpers

MATCHING="sha256:1111111111111111111111111111111111111111111111111111111111111111"
OTHER="sha256:2222222222222222222222222222222222222222222222222222222222222222"

# The registry's answer for a tag that is not published.
registry_says_absent() {
    export FAKE_SKOPEO_FAIL_ON="inspect"
    export FAKE_SKOPEO_STDERR="reading manifest x in ghcr.io/janrk/x: manifest unknown"
}

guard() {
    run --separate-stderr bash "$SCRIPTS_DIR/should-build.sh" "$@"
}

# --- version-pinned ---

@test "version: builds when the target tag is absent" {
    registry_says_absent
    guard --image ghcr.io/janrk/nginx --target-tag 1.28.0 --track version
    [ "$status" -eq 0 ]
    [ "$output" = "decision=build" ]
    log_has "docker://ghcr.io/janrk/nginx:1.28.0"
}

@test "version: skips when the target tag already exists" {
    guard --image ghcr.io/janrk/nginx --target-tag 1.28.0 --track version
    [ "$status" -eq 0 ]
    [ "$output" = "decision=skip" ]
}

# --- digest-tracked ---

@test "digest: builds when the target tag is absent" {
    registry_says_absent
    guard --image ghcr.io/janrk/searxng --target-tag latest --track digest --digest "$MATCHING"
    [ "$status" -eq 0 ]
    [ "$output" = "decision=build" ]
}

@test "digest: skips when the target digest matches upstream" {
    export FAKE_SKOPEO_DIGEST="$MATCHING"
    guard --image ghcr.io/janrk/searxng --target-tag latest --track digest --digest "$MATCHING"
    [ "$status" -eq 0 ]
    [ "$output" = "decision=skip" ]
}

@test "digest: builds when the target digest differs from upstream" {
    export FAKE_SKOPEO_DIGEST="$OTHER"
    guard --image ghcr.io/janrk/searxng --target-tag latest --track digest --digest "$MATCHING"
    [ "$status" -eq 0 ]
    [ "$output" = "decision=build" ]
}

# --- validation ---

@test "never prints build when the registry cannot be observed" {
    export FAKE_SKOPEO_FAIL_ON="inspect"
    export FAKE_SKOPEO_STDERR="received unexpected HTTP status: 403 Forbidden"
    guard --image ghcr.io/janrk/nginx --target-tag 1.28.0 --track version
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"403 Forbidden"* ]]
}

@test "fails without a target tag" {
    guard --image ghcr.io/janrk/x --track version
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--target-tag is required"* ]]
}

@test "fails without a track, rather than defaulting one" {
    guard --image ghcr.io/janrk/x --target-tag 1.0
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--track is required"* ]]
}

@test "fails on an unknown track" {
    guard --image ghcr.io/janrk/x --target-tag 1.0 --track sideways
    [ "$status" -ne 0 ]
}

@test "digest: fails without an upstream digest to compare against" {
    guard --image ghcr.io/janrk/searxng --target-tag latest --track digest
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"--digest"* ]]
}

@test "takes no --plan: the marker is the reader's alone" {
    printf '{}' > "$TEST_TMP/plan.json"
    guard --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/x --target-tag 1.0 --track version
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"unknown argument: --plan"* ]]
}
