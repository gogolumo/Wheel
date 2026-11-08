#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
script="$repo_root/scripts/prepare-spike-001-physical.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fail() {
    echo "SPIKE-001 physical preparation tests FAILED: $1" >&2
    exit 1
}

required_handoff=(
    'echo "SPIKE-001 physical preparation PASS"'
    'bash scripts/run-spike-001-slot.sh caps-lock-built-in'
    'bash scripts/run-spike-001-slot.sh caps-lock-external'
    'bash scripts/run-spike-001-slot.sh right-option-built-in'
    'bash scripts/run-spike-001-slot.sh right-option-external'
)
for text in "${required_handoff[@]}"; do
    grep -Fq -- "$text" "$script" \
        || fail "successful preparation handoff is incomplete"
done
if grep -Fq -- "swift run wheel-input-diagnostics" "$script"; then
    fail "stale diagnostics handoff returned"
fi

assert_failure() {
    local expected="$1"
    shift
    local output
    if output="$({ "$@"; } 2>&1)"; then
        fail "invalid preparation unexpectedly passed"
    fi
    [[ "$output" == "SPIKE-001 physical preparation FAILED: $expected" ]] \
        || fail "preparation emitted an unexpected diagnostic"
    [[ "$output" != *"$repo_root"* && "$output" != *"$test_root"* ]] \
        || fail "preparation diagnostic exposed a local path"
}

assert_failure \
    "summary destination must be outside the source checkout" \
    env WHEEL_CODESIGN_IDENTITY="private identity" \
    bash "$script" "$repo_root/private-evidence.json"

assert_failure \
    "WHEEL_CODESIGN_IDENTITY is required" \
    env -u WHEEL_CODESIGN_IDENTITY \
    bash "$script" "$test_root/evidence.json"

touch "$test_root/existing.json"
assert_failure \
    "summary destination must not already exist" \
    env WHEEL_CODESIGN_IDENTITY="private identity" \
    bash "$script" "$test_root/existing.json"

assert_failure \
    "expected an optional summary destination" \
    bash "$script" one two

echo "SPIKE-001 physical preparation tests PASS"
