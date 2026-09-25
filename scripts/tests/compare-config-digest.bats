#!/usr/bin/env bats
# compare-config-digest.sh — is the plan still about this job.yaml? Prints
# config=match or config=mismatch; the verdict is never the exit code.

load helpers

# The raw bytes below, hashed by the check plane's formula (SHA256.HashData,
# lowercase hex) — so a match here is the two planes agreeing, not bash
# agreeing with itself.
JOB_YAML=$'name: nginx\nmode: mirror\n'
JOB_DIGEST="sha256:fece591e3f30d13d88f3798500f2db5b25a0d454f7cc7ebfebe980517b2b5143"

setup_file() {
    CORPUS="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../tests/fixtures/markers" && pwd)"
    export CORPUS
}

write_marker() {  # configDigest
    jq --arg d "$1" '.configDigest = $d' "$CORPUS/mirror/valid/nginx.json" > "$TEST_TMP/marker.json"
    printf '%s' "$JOB_YAML" > "$TEST_TMP/job.yaml"
}

compare() {
    run --separate-stderr bash "$SCRIPTS_DIR/compare-config-digest.sh" \
        --marker "$TEST_TMP/marker.json" --job-yaml "$TEST_TMP/job.yaml"
}

@test "match: the marker was resolved from these exact job.yaml bytes" {
    write_marker "$JOB_DIGEST"
    compare
    [ "$status" -eq 0 ]
    [ "$output" = "config=match" ]
}

@test "mismatch: a comment-only edit changes the raw bytes, and still exits 0" {
    write_marker "$JOB_DIGEST"
    printf '# a comment\n' >> "$TEST_TMP/job.yaml"
    compare
    [ "$status" -eq 0 ]
    [ "$output" = "config=mismatch" ]
    [[ "$stderr" == *"$JOB_DIGEST"* ]]
}

@test "refuses a flat marker through the reader rather than comparing anything" {
    cp "$CORPUS/mirror/invalid/flat-no-plan.json" "$TEST_TMP/marker.json"
    printf '%s' "$JOB_YAML" > "$TEST_TMP/job.yaml"
    compare
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *"flat marker"* ]]
}

@test "refuses a missing job.yaml" {
    write_marker "$JOB_DIGEST"
    rm "$TEST_TMP/job.yaml"
    compare
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
}
