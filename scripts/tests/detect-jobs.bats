#!/usr/bin/env bats
# detect-jobs.sh — decide which jobs the build matrix should run.
# Prints jobs=<compact JSON array of job ids> on stdout; logs go to stderr.

load helpers

ZERO_SHA="0000000000000000000000000000000000000000"

makeJob() {  # repo-root id [enabled]
    local root="$1" id="$2" enabled="${3:-true}"
    mkdir -p "$root/jobs/$id"
    printf 'name: %s\nenabled: %s\nmode: mirror\n' "$id" "$enabled" > "$root/jobs/$id/job.yaml"
}

# Commit everything in $REPO and print the new commit's SHA.
commitAll() {
    git -C "$REPO" add -A
    git -C "$REPO" commit -q --allow-empty -m "$1"
    git -C "$REPO" rev-parse HEAD
}

# Change the given paths in one commit on top of BEFORE, and set SHA to it.
changePaths() {
    local p
    for p in "$@"; do
        mkdir -p "$REPO/$(dirname "$p")"
        printf '# changed\n' >> "$REPO/$p"
    done
    SHA="$(commitAll "change $*")"
}

setupRepo() {  # a real git repo: nginx(enabled) redis(enabled) old(disabled)
    # The diff is detect-jobs.sh's own behaviour now, so it needs the real git.
    rm -f "$FAKE_BIN/git"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME=bats GIT_AUTHOR_EMAIL=bats@example.invalid
    export GIT_COMMITTER_NAME=bats GIT_COMMITTER_EMAIL=bats@example.invalid
    REPO="$TEST_TMP/repo"
    mkdir -p "$REPO"
    git -C "$REPO" init -q
    makeJob "$REPO" nginx true
    makeJob "$REPO" redis true
    makeJob "$REPO" old   false
    BEFORE="$(commitAll initial)"
}

detect() {
    run --separate-stderr bash "$SCRIPTS_DIR/detect-jobs.sh" --repo-root "$REPO" "$@"
}

push() {
    detect --event push --before "$1" --sha "$2"
}

@test "dispatch with empty job builds all enabled jobs, sorted" {
    setupRepo
    detect --event workflow_dispatch --dispatch-job "" --before "" --sha "$BEFORE"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=["nginx","redis"]' ]
}

@test "dispatch with a named job builds just that one" {
    setupRepo
    detect --event workflow_dispatch --dispatch-job redis --before "" --sha "$BEFORE"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=["redis"]' ]
}

@test "dispatch with a named disabled job still builds it (explicit override)" {
    setupRepo
    detect --event workflow_dispatch --dispatch-job old --before "" --sha "$BEFORE"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=["old"]' ]
}

@test "dispatch with an unknown named job fails" {
    setupRepo
    detect --event workflow_dispatch --dispatch-job ghost --before "" --sha "$BEFORE"
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
}

@test "push with no before-SHA is a first run: all enabled jobs" {
    setupRepo
    push "" "$BEFORE"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=["nginx","redis"]' ]
}

@test "push from the all-zeros SHA (a new branch) is a first run: all enabled jobs" {
    setupRepo
    push "$ZERO_SHA" "$BEFORE"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=["nginx","redis"]' ]
}

@test "push from a before-SHA not in the clone (force-push) is a first run: all enabled jobs" {
    setupRepo
    push "1111111111111111111111111111111111111111" "$BEFORE"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=["nginx","redis"]' ]
}

@test "push builds a job whose jobs/<id>/ tree changed" {
    setupRepo
    changePaths jobs/nginx/Dockerfile
    push "$BEFORE" "$SHA"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=["nginx"]' ]
}

@test "push builds a job whose desired/<id>.json changed" {
    setupRepo
    changePaths desired/redis.json
    push "$BEFORE" "$SHA"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=["redis"]' ]
}

@test "push ignores shared-file edits (no auto-rebuild)" {
    setupRepo
    changePaths scripts/lib.sh .github/workflows/build.yaml README.md
    push "$BEFORE" "$SHA"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=[]' ]
}

@test "push excludes a changed but disabled job" {
    setupRepo
    changePaths jobs/old/job.yaml
    push "$BEFORE" "$SHA"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=[]' ]
}

@test "push collapses multiple paths into a sorted unique set" {
    setupRepo
    changePaths desired/redis.json jobs/nginx/Dockerfile jobs/nginx/entrypoint.sh
    push "$BEFORE" "$SHA"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=["nginx","redis"]' ]
}

@test "push with no changes yields an empty matrix" {
    setupRepo
    SHA="$(commitAll empty)"
    push "$BEFORE" "$SHA"
    [ "$status" -eq 0 ]
    [ "$output" = 'jobs=[]' ]
}

@test "push dies rather than guess when the diff itself fails" {
    setupRepo
    push "$BEFORE" "2222222222222222222222222222222222222222"
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
}

@test "push without --sha fails" {
    setupRepo
    detect --event push --before "$BEFORE"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--sha is required"* ]]
}

@test "takes no --changed-files: the diff is the script's own" {
    setupRepo
    printf 'jobs/nginx/Dockerfile\n' > "$TEST_TMP/changed"
    detect --event push --changed-files "$TEST_TMP/changed"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"unknown argument: --changed-files"* ]]
}

@test "an unknown event fails" {
    setupRepo
    detect --event release --before "" --sha "$BEFORE"
    [ "$status" -ne 0 ]
}
