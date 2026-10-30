#!/usr/bin/env bash

set -euo pipefail

fail() {
    echo "wheel-evidence-check CLI contract FAILED: $1" >&2
    exit 1
}

[[ $# -eq 1 ]] || fail "expected the wheel-evidence-check executable path"

checker="$1"
[[ -x "$checker" ]] || fail "checker executable is unavailable"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" \
    || fail "repository root is unavailable"
current_revision="$(git -C "$repo_root" rev-parse --verify HEAD 2>/dev/null)" \
    || fail "source revision is unavailable"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/wheel-evidence-check.XXXXXX")"
cleanup() {
    rm -rf "$test_root"
}
trap cleanup EXIT

valid_evidence="$test_root/private-valid-signed-build.json"
stale_evidence="$test_root/private-stale-signed-build.json"
missing_run="$test_root/private-missing-run.json"
stale_revision="0000000000000000000000000000000000000000"

write_evidence() {
    local path="$1"
    local revision="$2"

    printf '%s\n' \
        '{' \
        '  "schemaVersion": 1,' \
        '  "result": "pass",' \
        "  \"sourceRevision\": \"$revision\"," \
        '  "bundleIdentifier": "dev.gogolumo.Wheel",' \
        '  "packageType": "APPL",' \
        '  "backgroundApplication": true,' \
        '  "brandResourceVersion": 1,' \
        '  "signingTrust": "apple-generic"' \
        '}' >"$path"
}

assert_private_values_absent() {
    local output="$1"
    local label="$2"

    [[ "$output" != *"$test_root"* ]] \
        || fail "$label output disclosed a private path"
    [[ "$output" != *"$current_revision"* ]] \
        || fail "$label output disclosed the current revision"
    [[ "$output" != *"$stale_revision"* ]] \
        || fail "$label output disclosed the rejected revision"
}

write_evidence "$valid_evidence" "$current_revision"
if valid_output="$($checker \
    --profile spike-001-final \
    --signed-build-evidence "$valid_evidence" \
    "$missing_run" 2>&1)"; then
    fail "incomplete physical evidence unexpectedly passed"
fi
[[ "$valid_output" == *"Signed-build evidence: PASS"* ]] \
    || fail "valid signed-build evidence did not reach the CLI gate"
[[ "$valid_output" == *"Automated checks: FAILED"* ]] \
    || fail "missing physical evidence did not fail closed"
assert_private_values_absent "$valid_output" "valid-evidence"

write_evidence "$stale_evidence" "$stale_revision"
if stale_output="$($checker \
    --profile spike-001-final \
    --signed-build-evidence "$stale_evidence" \
    "$missing_run" 2>&1)"; then
    fail "stale signed-build evidence unexpectedly passed"
fi
[[ "$stale_output" == *"Signed-build evidence: FAILED"* ]] \
    || fail "stale signed-build evidence did not fail at the CLI gate"
[[ "$stale_output" != *"Signed-build evidence: PASS"* ]] \
    || fail "stale signed-build evidence emitted a contradictory PASS"
[[ "$stale_output" != *"Evidence file #1"* ]] \
    || fail "the CLI continued into physical evidence after a stale build"
assert_private_values_absent "$stale_output" "stale-evidence"

echo "wheel-evidence-check CLI contract tests PASS"
