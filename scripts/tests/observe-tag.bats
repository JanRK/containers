#!/usr/bin/env bats
# observe-tag.sh — the observation adapter, sole caller of `skopeo inspect`.
# Present and absent both exit 0; anything unclassified dies with stderr attached.

load helpers

DIGEST="sha256:1111111111111111111111111111111111111111111111111111111111111111"

@test "present: prints the digest of a published tag and exits 0" {
    export FAKE_SKOPEO_DIGEST="$DIGEST"
    run --separate-stderr bash "$SCRIPTS_DIR/observe-tag.sh" --ref ghcr.io/janrk/nginx:1.28.0
    [ "$status" -eq 0 ]
    [ "$output" = "present $DIGEST" ]
    log_has "inspect --retry-times 3 --format {{.Digest}} docker://ghcr.io/janrk/nginx:1.28.0"
}

@test "absent: a missing tag prints absent and still exits 0" {
    export FAKE_SKOPEO_FAIL_ON="inspect"
    # Measured against GHCR with credentials, 2026-09-23.
    export FAKE_SKOPEO_STDERR='time="2026-09-23T16:36:18+02:00" level=fatal msg="Error parsing image name \"docker://ghcr.io/janrk/nginx:9.9.9\": reading manifest 9.9.9 in ghcr.io/janrk/nginx: manifest unknown"'
    run --separate-stderr bash "$SCRIPTS_DIR/observe-tag.sh" --ref ghcr.io/janrk/nginx:9.9.9
    [ "$status" -eq 0 ]
    [ "$output" = "absent" ]
}

@test "unobservable: a 403 dies with the registry's stderr, never absent" {
    export FAKE_SKOPEO_FAIL_ON="inspect"
    # Measured against GHCR without credentials, 2026-09-23. The build plane is
    # authenticated, so here a 403 is simply broken.
    export FAKE_SKOPEO_STDERR='time="2026-09-23T16:36:51+02:00" level=fatal msg="Error parsing image name \"docker://ghcr.io/janrk/nginx:1.28.0\": fetching manifest 1.28.0 in ghcr.io/janrk/nginx: Requesting bearer token: received unexpected HTTP status: 403 Forbidden"'
    run --separate-stderr bash "$SCRIPTS_DIR/observe-tag.sh" --ref ghcr.io/janrk/nginx:1.28.0
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"403 Forbidden"* ]]
}

@test "unobservable: a failure with no stderr dies rather than reading as absent" {
    export FAKE_SKOPEO_FAIL_ON="inspect"
    run --separate-stderr bash "$SCRIPTS_DIR/observe-tag.sh" --ref ghcr.io/janrk/nginx:1.28.0
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"ghcr.io/janrk/nginx:1.28.0"* ]]
}

@test "unobservable: a zero exit that printed no digest dies" {
    export FAKE_SKOPEO_DIGEST=""
    run --separate-stderr bash "$SCRIPTS_DIR/observe-tag.sh" --ref ghcr.io/janrk/nginx:1.28.0
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
}

@test "requires --ref" {
    run --separate-stderr bash "$SCRIPTS_DIR/observe-tag.sh"
    [ "$status" -ne 0 ]
    run ! log_has "inspect"
}
