#!/usr/bin/env bats
# should-build.sh — registry-skip guard (decision 3). Re-checks the registry and
# prints "build" or "skip" so the build leg can short-circuit cheaply.

load helpers

writePlan() {  # path targetTag [digest]
    local path="$1" tag="$2" digest="${3:-}"
    if [ -n "$digest" ]; then
        jq -n --arg t "$tag" --arg d "$digest" '{name:"x", targetTag:$t, digest:$d}' > "$path"
    else
        jq -n --arg t "$tag" '{name:"x", targetTag:$t}' > "$path"
    fi
}

# --- version-pinned (default track) ---

@test "version: builds when the target tag is absent" {
    export FAKE_SKOPEO_FAIL_ON="inspect"
    writePlan "$TEST_TMP/plan.json" 1.28.0
    run --separate-stderr bash "$SCRIPTS_DIR/should-build.sh" \
        --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/nginx
    [ "$status" -eq 0 ]
    [ "$output" = "build" ]
}

@test "version: skips when the target tag already exists" {
    writePlan "$TEST_TMP/plan.json" 1.28.0
    run --separate-stderr bash "$SCRIPTS_DIR/should-build.sh" \
        --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/nginx
    [ "$status" -eq 0 ]
    [ "$output" = "skip" ]
}

# --- digest-tracked ---

@test "digest: builds when the target tag is absent" {
    export FAKE_SKOPEO_FAIL_ON="inspect"
    writePlan "$TEST_TMP/plan.json" latest sha256:aaaa
    run --separate-stderr bash "$SCRIPTS_DIR/should-build.sh" \
        --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/searxng --track digest
    [ "$status" -eq 0 ]
    [ "$output" = "build" ]
}

@test "digest: skips when the target digest matches upstream" {
    export FAKE_SKOPEO_DIGEST="sha256:matching"
    writePlan "$TEST_TMP/plan.json" latest sha256:matching
    run --separate-stderr bash "$SCRIPTS_DIR/should-build.sh" \
        --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/searxng --track digest
    [ "$status" -eq 0 ]
    [ "$output" = "skip" ]
}

@test "digest: builds when the target digest differs from upstream" {
    export FAKE_SKOPEO_DIGEST="sha256:current"
    writePlan "$TEST_TMP/plan.json" latest sha256:wanted
    run --separate-stderr bash "$SCRIPTS_DIR/should-build.sh" \
        --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/searxng --track digest
    [ "$status" -eq 0 ]
    [ "$output" = "build" ]
}

# --- validation ---

@test "fails when the plan has no targetTag" {
    jq -n '{name:"x"}' > "$TEST_TMP/plan.json"
    run --separate-stderr bash "$SCRIPTS_DIR/should-build.sh" \
        --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/x
    [ "$status" -ne 0 ]
}

@test "fails on an unknown track" {
    writePlan "$TEST_TMP/plan.json" 1.0
    run --separate-stderr bash "$SCRIPTS_DIR/should-build.sh" \
        --plan "$TEST_TMP/plan.json" --image ghcr.io/janrk/x --track sideways
    [ "$status" -ne 0 ]
}
