#!/usr/bin/env bats
# emit-result.sh — prints the result artifact record.sh folds into state/.
# Owns the fatal digest read: a tag it cannot read back is an error, not an absence.

load helpers

DIGEST="sha256:2222222222222222222222222222222222222222222222222222222222222222"

emit() {
    run --separate-stderr bash "$SCRIPTS_DIR/emit-result.sh" \
        --name nginx --image ghcr.io/janrk/nginx --built-tag 1.28.0 \
        --resolved '{"nginx":"1.28.0"}'
}

@test "prints name, builtTag, the read-back builtDigest, builtAt and resolved" {
    export FAKE_SKOPEO_DIGEST="$DIGEST"
    emit
    [ "$status" -eq 0 ]
    [ "$(jq -r '.name' <<<"$output")" = "nginx" ]
    [ "$(jq -r '.builtTag' <<<"$output")" = "1.28.0" ]
    [ "$(jq -r '.builtDigest' <<<"$output")" = "$DIGEST" ]
    [ "$(jq -r '.builtAt' <<<"$output")" = "2026-06-20T12:00:00Z" ]
    [ "$(jq -c '.resolved' <<<"$output")" = '{"nginx":"1.28.0"}' ]
    log_has "docker://ghcr.io/janrk/nginx:1.28.0"
}

@test "dies rather than print an empty builtDigest when the pushed tag reads back absent" {
    export FAKE_SKOPEO_FAIL_ON="inspect"
    export FAKE_SKOPEO_STDERR="reading manifest 1.28.0 in ghcr.io/janrk/nginx: manifest unknown"
    emit
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"ghcr.io/janrk/nginx:1.28.0"* ]]
}

@test "dies rather than print an empty builtDigest when the read-back fails" {
    export FAKE_SKOPEO_FAIL_ON="inspect"
    export FAKE_SKOPEO_STDERR="received unexpected HTTP status: 503 Service Unavailable"
    emit
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"503 Service Unavailable"* ]]
}

@test "refuses a --resolved that is not a JSON object" {
    run --separate-stderr bash "$SCRIPTS_DIR/emit-result.sh" \
        --name nginx --image ghcr.io/janrk/nginx --built-tag 1.28.0 --resolved '["1.28.0"]'
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"--resolved"* ]]
}
