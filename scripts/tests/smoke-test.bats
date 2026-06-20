#!/usr/bin/env bats
# smoke-test.sh — run the job's { entrypoint, args[], expect? } checks.

load helpers

@test "runs each test with its entrypoint and args" {
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/multica-agent:m1 \
        --tests '[{"entrypoint":"multica","args":["--version"]},{"entrypoint":"sh","args":["-c","test -f /app/entrypoint.sh"]}]'
    [ "$status" -eq 0 ]
    log_has "run --rm --entrypoint multica ghcr.io/janrk/multica-agent:m1 --version"
    log_has "run --rm --entrypoint sh ghcr.io/janrk/multica-agent:m1 -c test -f /app/entrypoint.sh"
    [ "$(log_count docker)" -eq 2 ]
}

@test "runs an entrypoint with no args" {
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/x:1 \
        --tests '[{"entrypoint":"true"}]'
    [ "$status" -eq 0 ]
    log_has "run --rm --entrypoint true ghcr.io/janrk/x:1"
}

@test "passes when expect substring is present in output" {
    export FAKE_DOCKER_STDOUT="multica version 1.2.3"
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/x:1 \
        --tests '[{"entrypoint":"multica","args":["--version"],"expect":"version 1.2.3"}]'
    [ "$status" -eq 0 ]
}

@test "fails when expect substring is absent from output" {
    export FAKE_DOCKER_STDOUT="nope"
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/x:1 \
        --tests '[{"entrypoint":"multica","args":["--version"],"expect":"version 1.2.3"}]'
    [ "$status" -ne 0 ]
}

@test "is a no-op when there are no tests" {
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/x:1 --tests '[]'
    [ "$status" -eq 0 ]
    [ ! -s "$CALL_LOG" ]
}

@test "is a no-op when tests is null" {
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/x:1 --tests 'null'
    [ "$status" -eq 0 ]
    [ ! -s "$CALL_LOG" ]
}

@test "is a no-op when --tests is omitted" {
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/x:1
    [ "$status" -eq 0 ]
    [ ! -s "$CALL_LOG" ]
}

@test "fails when a test exits non-zero" {
    export FAKE_DOCKER_FAIL_ON="boom"
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/x:1 \
        --tests '[{"entrypoint":"boom"}]'
    [ "$status" -ne 0 ]
}

@test "fails on an entry without an entrypoint" {
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/x:1 \
        --tests '[{"args":["--version"]}]'
    [ "$status" -ne 0 ]
}

@test "fails on an invalid --tests json" {
    run --separate-stderr bash "$SCRIPTS_DIR/smoke-test.sh" --image ghcr.io/janrk/x:1 --tests 'not json'
    [ "$status" -ne 0 ]
}
