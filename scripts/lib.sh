#!/usr/bin/env bash
# Shared helpers for the GitHub build pipeline scripts.
# Source this file; it defines functions only and runs nothing on its own.

# Log a line to stderr with a ">>" marker so it stands out in CI logs.
log() { printf '>> %s\n' "$*" >&2; }

# Log an error and abort with a non-zero status.
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Current UTC timestamp in the marker format (yyyy-MM-ddTHH:mm:ssZ).
now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# Abort unless every named command is on PATH.
require_cmd() {
    local c
    for c in "$@"; do
        command -v "$c" >/dev/null 2>&1 || die "required command not found: $c"
    done
}

# Read a required string field from a JSON file; die if null/missing.
# Usage: value="$(json_req <file> <jq-filter> <label>)"
json_req() {
    local file="$1" filter="$2" label="$3" value
    value="$(jq -er "$filter" "$file" 2>/dev/null)" \
        || die "plan $file missing required field: $label"
    printf '%s' "$value"
}

# Emit a build/mirror result artifact consumed by record.sh.
# Usage: emit_result <plan> <image> <targetTag> <result-path>
emit_result() {
    local plan="$1" image="$2" target_tag="$3" result="$4"
    local name built_digest resolved
    name="$(jq -r '.name' "$plan")"
    built_digest="$(skopeo inspect --retry-times 3 --format '{{.Digest}}' \
        "docker://$image:$target_tag" 2>/dev/null || true)"
    resolved="$(jq -c '.resolved // {}' "$plan")"
    jq -n \
        --arg name "$name" \
        --arg builtTag "$target_tag" \
        --arg builtDigest "$built_digest" \
        --arg builtAt "${BUILT_AT:-$(now_utc)}" \
        --argjson resolved "$resolved" \
        '{name:$name, builtTag:$builtTag, builtDigest:$builtDigest, builtAt:$builtAt, resolved:$resolved}' \
        > "$result"
    log "wrote result artifact $result"
}
