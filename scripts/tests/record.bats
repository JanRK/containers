#!/usr/bin/env bats
# record.sh — turn build-result artifacts into state receipts + capped history.

load helpers

writeArtifact() {  # path name builtTag [builtDigest]
    local path="$1" name="$2" tag="$3" digest="${4:-sha256:abc}"
    jq -n --arg n "$name" --arg t "$tag" --arg d "$digest" \
        '{name:$n, builtTag:$t, builtDigest:$d, builtAt:"2026-06-20T12:00:00Z", resolved:{version:$t}}' \
        > "$path"
}

@test "writes a state receipt with only the receipt fields" {
    mkdir -p "$TEST_TMP/art"
    writeArtifact "$TEST_TMP/art/nginx.json" nginx 1.28.0 sha256:deadbeef
    run bash "$SCRIPTS_DIR/record.sh" --artifacts "$TEST_TMP/art" \
        --state-dir "$TEST_TMP/state" --history-dir "$TEST_TMP/history"
    [ "$status" -eq 0 ]

    local r="$TEST_TMP/state/nginx.json"
    [ -f "$r" ]
    [ "$(jq -r '.name' "$r")" = "nginx" ]
    [ "$(jq -r '.builtTag' "$r")" = "1.28.0" ]
    [ "$(jq -r '.builtDigest' "$r")" = "sha256:deadbeef" ]
    [ "$(jq -r '.builtAt' "$r")" = "2026-06-20T12:00:00Z" ]
    [ "$(jq -r 'has("resolved")' "$r")" = "false" ]
}

@test "creates a new history with a single newest-first entry" {
    mkdir -p "$TEST_TMP/art"
    writeArtifact "$TEST_TMP/art/nginx.json" nginx 1.28.0
    run bash "$SCRIPTS_DIR/record.sh" --artifacts "$TEST_TMP/art" \
        --state-dir "$TEST_TMP/state" --history-dir "$TEST_TMP/history"
    [ "$status" -eq 0 ]

    local h="$TEST_TMP/history/nginx.json"
    [ "$(jq -r 'length' "$h")" = "1" ]
    [ "$(jq -r '.[0].builtTag' "$h")" = "1.28.0" ]
    [ "$(jq -r '.[0].resolved.version' "$h")" = "1.28.0" ]
    [ "$(jq -r '.[0] | has("builtDigest")' "$h")" = "true" ]
}

@test "prepends to existing history, newest first" {
    mkdir -p "$TEST_TMP/art" "$TEST_TMP/history"
    jq -n '[{builtTag:"1.27.0", resolved:{version:"1.27.0"}, builtDigest:"sha256:old", builtAt:"t0"}]' \
        > "$TEST_TMP/history/nginx.json"
    writeArtifact "$TEST_TMP/art/nginx.json" nginx 1.28.0
    run bash "$SCRIPTS_DIR/record.sh" --artifacts "$TEST_TMP/art" \
        --state-dir "$TEST_TMP/state" --history-dir "$TEST_TMP/history"
    [ "$status" -eq 0 ]

    local h="$TEST_TMP/history/nginx.json"
    [ "$(jq -r 'length' "$h")" = "2" ]
    [ "$(jq -r '.[0].builtTag' "$h")" = "1.28.0" ]
    [ "$(jq -r '.[1].builtTag' "$h")" = "1.27.0" ]
}

@test "caps history at 30 by default, dropping the oldest" {
    mkdir -p "$TEST_TMP/art" "$TEST_TMP/history"
    jq -n '[range(30) | {builtTag:("v"+(.|tostring)), resolved:{}, builtDigest:"sha256:x", builtAt:"t"}]' \
        > "$TEST_TMP/history/nginx.json"
    writeArtifact "$TEST_TMP/art/nginx.json" nginx new
    run bash "$SCRIPTS_DIR/record.sh" --artifacts "$TEST_TMP/art" \
        --state-dir "$TEST_TMP/state" --history-dir "$TEST_TMP/history"
    [ "$status" -eq 0 ]

    local h="$TEST_TMP/history/nginx.json"
    [ "$(jq -r 'length' "$h")" = "30" ]
    [ "$(jq -r '.[0].builtTag' "$h")" = "new" ]
    [ "$(jq -r '.[29].builtTag' "$h")" = "v28" ]
}

@test "honours a custom history cap" {
    mkdir -p "$TEST_TMP/art" "$TEST_TMP/history"
    jq -n '[range(3) | {builtTag:("v"+(.|tostring)), resolved:{}, builtDigest:"sha256:x", builtAt:"t"}]' \
        > "$TEST_TMP/history/nginx.json"
    writeArtifact "$TEST_TMP/art/nginx.json" nginx new
    run bash "$SCRIPTS_DIR/record.sh" --artifacts "$TEST_TMP/art" \
        --state-dir "$TEST_TMP/state" --history-dir "$TEST_TMP/history" --history-cap 3
    [ "$status" -eq 0 ]
    [ "$(jq -r 'length' "$TEST_TMP/history/nginx.json")" = "3" ]
}

@test "processes multiple artifacts independently" {
    mkdir -p "$TEST_TMP/art"
    writeArtifact "$TEST_TMP/art/nginx.json" nginx 1.28.0
    writeArtifact "$TEST_TMP/art/redis.json" redis 7.4.0
    run bash "$SCRIPTS_DIR/record.sh" --artifacts "$TEST_TMP/art" \
        --state-dir "$TEST_TMP/state" --history-dir "$TEST_TMP/history"
    [ "$status" -eq 0 ]
    [ "$(jq -r '.builtTag' "$TEST_TMP/state/nginx.json")" = "1.28.0" ]
    [ "$(jq -r '.builtTag' "$TEST_TMP/state/redis.json")" = "7.4.0" ]
}

@test "creates the state and history directories if missing" {
    mkdir -p "$TEST_TMP/art"
    writeArtifact "$TEST_TMP/art/nginx.json" nginx 1.28.0
    run bash "$SCRIPTS_DIR/record.sh" --artifacts "$TEST_TMP/art" \
        --state-dir "$TEST_TMP/deep/state" --history-dir "$TEST_TMP/deep/history"
    [ "$status" -eq 0 ]
    [ -d "$TEST_TMP/deep/state" ]
    [ -d "$TEST_TMP/deep/history" ]
}

@test "fails when an artifact is missing a required field" {
    mkdir -p "$TEST_TMP/art"
    jq -n '{name:"nginx", builtDigest:"sha256:x", builtAt:"t", resolved:{}}' \
        > "$TEST_TMP/art/nginx.json"
    run bash "$SCRIPTS_DIR/record.sh" --artifacts "$TEST_TMP/art" \
        --state-dir "$TEST_TMP/state" --history-dir "$TEST_TMP/history"
    [ "$status" -ne 0 ]
}

@test "ignores non-json files in the artifacts directory" {
    mkdir -p "$TEST_TMP/art"
    writeArtifact "$TEST_TMP/art/nginx.json" nginx 1.28.0
    echo "not json" > "$TEST_TMP/art/README.txt"
    run bash "$SCRIPTS_DIR/record.sh" --artifacts "$TEST_TMP/art" \
        --state-dir "$TEST_TMP/state" --history-dir "$TEST_TMP/history"
    [ "$status" -eq 0 ]
    [ "$(ls "$TEST_TMP/state" | wc -l)" -eq 1 ]
}
