#!/usr/bin/env bats
# read-plan.sh — the plan reader, sole opener of a marker. Driven by the shared
# fixture corpus github/tests/fixtures/markers/ (ADR-0010); the check plane's
# Pester suite reads the same files.

load helpers

setup_file() {
    CORPUS="$(cd "$(dirname "$BATS_TEST_FILENAME")/../../tests/fixtures/markers" && pwd)"
    export CORPUS
}

read_plan() {
    run --separate-stderr bash "$SCRIPTS_DIR/read-plan.sh" --marker "$1"
}

# Assert the reader printed this exact line.
has_line() {
    grep -qxF -- "$1" <<<"$output" || { echo "missing line: $1"; echo "output: $output"; return 1; }
}

@test "reads a local-dockerfile marker into key=value lines" {
    read_plan "$CORPUS/local/valid/airlock.json"
    [ "$status" -eq 0 ]
    has_line "name=airlock"
    has_line "mode=local-dockerfile"
    has_line "image=ghcr.io/janrk/airlock"
    has_line "track=version"
    has_line "targetTag=v1.4.0-btrixie-20260112"
    has_line 'extraTags=[]'
    has_line 'resolved={"app":"1.4.0","base":"trixie-20260112"}'
    has_line "platforms=linux/amd64"
    has_line 'test=[{"entrypoint":"/usr/local/bin/airlock","args":["--version"]}]'
    has_line 'buildArgs={"BASE_TAG":"trixie-20260112","APP_VERSION":"1.4.0"}'
    has_line "dockerfile=jobs/airlock/Dockerfile"
    has_line "context=jobs/airlock"
    has_line "configDigest=sha256:2be9b52780505880fb2bd029804c66c75eebf856c47757c325e94f79d061f356"
    has_line "desiredAt=2026-01-14T09:31:02Z"
    has_line "firstDesiredAt=2026-01-14T09:31:02Z"
    has_line "attempt=1"
}

@test "reads a remote-dockerfile marker, clone coordinates included" {
    read_plan "$CORPUS/remote/valid/routa.json"
    [ "$status" -eq 0 ]
    has_line "mode=remote-dockerfile"
    has_line "repo=https://github.com/acme/routa"
    has_line "ref=v1.4.0"
    has_line 'buildArgs={}'
    has_line "dockerfile=docker/Dockerfile"
    has_line "context=."
    has_line "platforms=linux/amd64,linux/arm64"
}

@test "reads a digest-tracked mirror marker, digest included" {
    read_plan "$CORPUS/mirror/valid/searxng.json"
    [ "$status" -eq 0 ]
    has_line "mode=mirror"
    has_line "track=digest"
    has_line "mirrorSource=docker.io/searxng/searxng@sha256:3f4a1d6b1e0c8a5d2b7e9f0c4a6d8b1e3f5a7c9d0b2e4f6a8c0d2e4f6a8c0d2e"
    has_line "digest=sha256:3f4a1d6b1e0c8a5d2b7e9f0c4a6d8b1e3f5a7c9d0b2e4f6a8c0d2e4f6a8c0d2e"
    run ! grep -q '^buildArgs=' <<<"$output"
}

@test "the corpus has valid and invalid markers for every mode" {
    # Not data-driven, deliberately: a loop over an empty or mistyped corpus
    # passes having asserted nothing (spec 10.4).
    local mode half
    for mode in mirror local remote; do
        for half in valid invalid; do
            [ -d "$CORPUS/$mode/$half" ] || { echo "missing $mode/$half"; return 1; }
            compgen -G "$CORPUS/$mode/$half/*.json" >/dev/null || { echo "empty $mode/$half"; return 1; }
        done
    done
}

@test "every valid marker reads, printing only key=value lines" {
    local f
    for f in "$CORPUS"/*/valid/*.json; do
        read_plan "$f"
        [ "$status" -eq 0 ] || { echo "refused $f: $stderr"; return 1; }
        ! grep -qvE '^[A-Za-z]+=.+$' <<<"$output" || { echo "bad line from $f: $output"; return 1; }
        grep -q '^configDigest=sha256:' <<<"$output" || { echo "no configDigest from $f"; return 1; }
    done
}

# The reason each malformed marker must be refused with. A new invalid fixture
# fails the suite until it is given one here.
expected_reason() {
    case "$1" in
        flat-no-plan.json)                 echo "flat marker" ;;
        missing-attempt.json)              echo ".attempt is missing" ;;
        missing-config-digest.json)        echo ".configDigest is missing" ;;
        missing-target-tag.json)           echo ".plan.targetTag is missing" ;;
        missing-ref.json)                  echo ".plan.ref is missing" ;;
        null-build-args.json)              echo ".plan.buildArgs is missing, null" ;;
        null-mirror-source.json)           echo ".plan.mirrorSource is missing, null" ;;
        digest-track-without-digest.json)  echo ".plan.digest is missing" ;;
        unexpanded-ref.json)               echo "unexpanded placeholder in 'v{app}'" ;;
        *) return 1 ;;
    esac
}

@test "every invalid marker is refused by the reader, with the reason, printing nothing" {
    local f reason
    for f in "$CORPUS"/*/invalid/*.json; do
        reason="$(expected_reason "$(basename "$f")")" \
            || { echo "no expected reason for $f"; return 1; }
        read_plan "$f"
        [ "$status" -ne 0 ] || { echo "accepted $f"; return 1; }
        [ "$output" = "" ] || { echo "printed a partial plan for $f: $output"; return 1; }
        [[ "$stderr" == *"$f"* ]] || { echo "reason does not name $f: $stderr"; return 1; }
        [[ "$stderr" == *"$reason"* ]] || { echo "wrong reason for $f: $stderr"; return 1; }
    done
}

@test "refuses a value that would inject a second output line" {
    jq '.plan.targetTag = "1.0\nimage=evil"' "$CORPUS/local/valid/airlock.json" > "$TEST_TMP/m.json"
    read_plan "$TEST_TMP/m.json"
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *".plan.targetTag spans more than one line"* ]]
}

@test "refuses a carriage return, which also ends an output line" {
    jq '.plan.targetTag = "1.0\rimage=evil"' "$CORPUS/local/valid/airlock.json" > "$TEST_TMP/m.json"
    read_plan "$TEST_TMP/m.json"
    [ "$status" -ne 0 ]
    [ "$output" = "" ]
    [[ "$stderr" == *".plan.targetTag spans more than one line"* ]]
}

@test "refuses a marker that is not JSON" {
    printf 'not json' > "$TEST_TMP/m.json"
    read_plan "$TEST_TMP/m.json"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"not valid JSON"* ]]
}

@test "refuses a missing marker file" {
    read_plan "$TEST_TMP/nope.json"
    [ "$status" -ne 0 ]
    [[ "$stderr" == *"marker not found"* ]]
}
