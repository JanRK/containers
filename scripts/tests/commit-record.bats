#!/usr/bin/env bats
# commit-record.sh — commit and push what record.sh wrote, as the bot, or skip
# cleanly when nothing changed. Real git: a work clone and a bare remote.

load helpers

setup_repo() {
    rm -f "$FAKE_BIN/git"
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    REMOTE="$TEST_TMP/remote.git"
    WORK="$TEST_TMP/work"
    git init -q --bare "$REMOTE"
    git clone -q "$REMOTE" "$WORK" 2>/dev/null
    printf 'seed\n' > "$WORK/README.md"
    git -C "$WORK" add README.md
    git -C "$WORK" -c user.name=seed -c user.email=seed@example.invalid commit -q -m seed
    git -C "$WORK" push -q origin HEAD 2>/dev/null
}

commit_record() {
    run --separate-stderr bash "$SCRIPTS_DIR/commit-record.sh" --repo-root "$WORK" \
        --name container-bot --email container-bot@users.noreply.github.com \
        --message "record: update build state and history" \
        --path state --path history "$@"
}

remote_log() { git -C "$REMOTE" log --format='%an <%ae> %s' "$@"; }

@test "commits the recorded paths as the bot and pushes them" {
    setup_repo
    mkdir -p "$WORK/state" "$WORK/history"
    printf '{}\n' > "$WORK/state/nginx.json"
    printf '[]\n' > "$WORK/history/nginx.json"
    commit_record
    [ "$status" -eq 0 ]
    [ "$(remote_log -1)" = "container-bot <container-bot@users.noreply.github.com> record: update build state and history" ]
    [ "$(git -C "$REMOTE" show --name-only --format= HEAD | sort | tr '\n' ' ')" = "history/nginx.json state/nginx.json " ]
}

@test "skips cleanly when nothing under the paths changed" {
    setup_repo
    printf 'unrelated\n' > "$WORK/other.txt"
    commit_record
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
    [ "$(remote_log | wc -l)" -eq 1 ]
    [[ "$stderr" == *"nothing to commit"* ]]
}

@test "commits only the given paths" {
    setup_repo
    mkdir -p "$WORK/state"
    printf '{}\n' > "$WORK/state/nginx.json"
    printf 'unrelated\n' > "$WORK/other.txt"
    commit_record
    [ "$status" -eq 0 ]
    [ "$(git -C "$REMOTE" show --name-only --format= HEAD)" = "state/nginx.json" ]
}

@test "leaves the clone's git config untouched" {
    setup_repo
    mkdir -p "$WORK/state"
    printf '{}\n' > "$WORK/state/nginx.json"
    commit_record
    [ "$status" -eq 0 ]
    run git -C "$WORK" config --local user.name
    [ "$status" -ne 0 ]
}

@test "propagates a push failure" {
    setup_repo
    mkdir -p "$WORK/state"
    printf '{}\n' > "$WORK/state/nginx.json"
    rm -rf "$REMOTE"
    commit_record
    [ "$status" -ne 0 ]
}

@test "requires at least one path" {
    setup_repo
    run --separate-stderr bash "$SCRIPTS_DIR/commit-record.sh" --repo-root "$WORK" \
        --name container-bot --email container-bot@users.noreply.github.com --message m
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--path is required"* ]]
}

@test "requires the author identity" {
    setup_repo
    run --separate-stderr bash "$SCRIPTS_DIR/commit-record.sh" --repo-root "$WORK" \
        --message m --path state
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"--name is required"* ]]
}
