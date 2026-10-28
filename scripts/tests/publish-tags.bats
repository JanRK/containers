#!/usr/bin/env bats
# publish-tags.sh — tags a smoke-tested digest and writes its receipt artifact.

load helpers

DIGEST="sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
RECIPE_DIGEST="sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

publish_tags() {
    run --separate-stderr bash "$SCRIPTS_DIR/publish-tags.sh" \
        --image ghcr.io/janrk/nginx --digest "$DIGEST" --target-tag 1.28.0 \
        --extra-tags '["latest","stable"]' --name nginx \
        --resolved '{"nginx":"1.28.0"}' --recipe-digest "$RECIPE_DIGEST" \
        --result "$TEST_TMP/result.json" "$@"
}

@test "creates the target and extra tags from the digest, without annotations" {
    publish_tags
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    log_has "docker buildx imagetools create -t ghcr.io/janrk/nginx:1.28.0 -t ghcr.io/janrk/nginx:latest -t ghcr.io/janrk/nginx:stable ghcr.io/janrk/nginx@$DIGEST"
    ! log_has "--annotation"
}

@test "rejects an invalid digest before invoking docker" {
    publish_tags --digest sha256:BAD
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"--digest must be sha256:<64 hex>: sha256:BAD"* ]]
    ! log_has "docker"
}

@test "propagates imagetools failure without writing a result" {
    export FAKE_DOCKER_FAIL_ON=imagetools
    publish_tags
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [ ! -e "$TEST_TMP/result.json" ]
    ! log_has "skopeo"
}

@test "writes the recipe digest and read-back built digest" {
    export FAKE_SKOPEO_DIGEST="sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    publish_tags
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    [ "$(jq -r '.recipeDigest' "$TEST_TMP/result.json")" = "$RECIPE_DIGEST" ]
    [ "$(jq -r '.builtDigest' "$TEST_TMP/result.json")" = "$FAKE_SKOPEO_DIGEST" ]
    [ "$(jq -r '.builtTag' "$TEST_TMP/result.json")" = "1.28.0" ]
    log_has "docker://ghcr.io/janrk/nginx:1.28.0"
}

@test "rejects extra tags that are not a JSON array of strings" {
    publish_tags --extra-tags latest
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--extra-tags must be a JSON array of strings: latest"* ]]
    ! log_has "docker"
}

@test "each argument is required" {
    local missing argument_index
    local -a required=(
        --image ghcr.io/janrk/nginx
        --digest "$DIGEST"
        --target-tag 1.28.0
        --extra-tags '["latest","stable"]'
        --name nginx
        --resolved '{"nginx":"1.28.0"}'
        --recipe-digest "$RECIPE_DIGEST"
        --result "$TEST_TMP/result.json"
    )
    for missing in --image --digest --target-tag --extra-tags --name --resolved --recipe-digest --result; do
        local -a args=()
        for ((argument_index = 0; argument_index < ${#required[@]}; argument_index += 2)); do
            if [ "${required[argument_index]}" = "$missing" ]; then
                continue
            fi
            args+=("${required[argument_index]}" "${required[argument_index + 1]}")
        done
        run --separate-stderr bash "$SCRIPTS_DIR/publish-tags.sh" "${args[@]}"
        [ "$status" -ne 0 ]
        [[ "$stderr" == *"$missing is required"* ]]
        ! log_has "docker"
    done
}