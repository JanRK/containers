#!/usr/bin/env bats
# detect-jobs.sh — decide which jobs the build matrix should run.
# Emits a compact JSON array of job ids on stdout; logs go to stderr.

load helpers

makeJob() {  # repo-root id [enabled]
    local root="$1" id="$2" enabled="${3:-true}"
    mkdir -p "$root/jobs/$id"
    printf 'name: %s\nenabled: %s\nmode: mirror\n' "$id" "$enabled" > "$root/jobs/$id/job.yaml"
}

setupRepo() {  # creates nginx(enabled) redis(enabled) old(disabled)
    REPO="$TEST_TMP/repo"
    makeJob "$REPO" nginx true
    makeJob "$REPO" redis true
    makeJob "$REPO" old   false
}

@test "dispatch with empty job builds all enabled jobs, sorted" {
    setupRepo
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event workflow_dispatch --repo-root "$REPO" --dispatch-job ""
    [ "$status" -eq 0 ]
    [ "$output" = '["nginx","redis"]' ]
}

@test "dispatch with a named job builds just that one" {
    setupRepo
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event workflow_dispatch --repo-root "$REPO" --dispatch-job redis
    [ "$status" -eq 0 ]
    [ "$output" = '["redis"]' ]
}

@test "dispatch with a named disabled job still builds it (explicit override)" {
    setupRepo
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event workflow_dispatch --repo-root "$REPO" --dispatch-job old
    [ "$status" -eq 0 ]
    [ "$output" = '["old"]' ]
}

@test "dispatch with an unknown named job fails" {
    setupRepo
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event workflow_dispatch --repo-root "$REPO" --dispatch-job ghost
    [ "$status" -ne 0 ]
}

@test "push first-run builds all enabled jobs" {
    setupRepo
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event push --repo-root "$REPO" --first-run true
    [ "$status" -eq 0 ]
    [ "$output" = '["nginx","redis"]' ]
}

@test "push builds a job whose jobs/<id>/ tree changed" {
    setupRepo
    printf 'jobs/nginx/Dockerfile\n' > "$TEST_TMP/changed"
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event push --repo-root "$REPO" --changed-files "$TEST_TMP/changed"
    [ "$status" -eq 0 ]
    [ "$output" = '["nginx"]' ]
}

@test "push builds a job whose desired/<id>.json changed" {
    setupRepo
    printf 'desired/redis.json\n' > "$TEST_TMP/changed"
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event push --repo-root "$REPO" --changed-files "$TEST_TMP/changed"
    [ "$status" -eq 0 ]
    [ "$output" = '["redis"]' ]
}

@test "push ignores shared-file edits (no auto-rebuild)" {
    setupRepo
    printf 'scripts/lib.sh\n.github/workflows/build.yaml\nREADME.md\n' > "$TEST_TMP/changed"
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event push --repo-root "$REPO" --changed-files "$TEST_TMP/changed"
    [ "$status" -eq 0 ]
    [ "$output" = '[]' ]
}

@test "push excludes a changed but disabled job" {
    setupRepo
    printf 'jobs/old/job.yaml\n' > "$TEST_TMP/changed"
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event push --repo-root "$REPO" --changed-files "$TEST_TMP/changed"
    [ "$status" -eq 0 ]
    [ "$output" = '[]' ]
}

@test "push collapses multiple paths into a sorted unique set" {
    setupRepo
    printf 'desired/redis.json\njobs/nginx/Dockerfile\njobs/nginx/entrypoint.sh\n' > "$TEST_TMP/changed"
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event push --repo-root "$REPO" --changed-files "$TEST_TMP/changed"
    [ "$status" -eq 0 ]
    [ "$output" = '["nginx","redis"]' ]
}

@test "push with no relevant changes yields an empty matrix" {
    setupRepo
    : > "$TEST_TMP/changed"
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event push --repo-root "$REPO" --changed-files "$TEST_TMP/changed"
    [ "$status" -eq 0 ]
    [ "$output" = '[]' ]
}

@test "an unknown event fails" {
    setupRepo
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" \
        --event release --repo-root "$REPO"
    [ "$status" -ne 0 ]
}
