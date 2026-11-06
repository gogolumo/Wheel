#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
script="$repo_root/scripts/run-spike-001-slot.sh"
test_root="$(mktemp -d)"
fake_bin="$test_root/bin"
invocation_log="$test_root/swift-invocation"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$fake_bin"

fail() {
    echo "SPIKE-001 physical slot tests FAILED: $1" >&2
    exit 1
}

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
case "$*" in
    *"rev-parse --verify @{upstream}"*)
        printf '%s\n' "${WHEEL_SLOT_TEST_UPSTREAM:-0123456789012345678901234567890123456789}"
        ;;
    *"rev-parse --verify HEAD"*)
        printf '%s\n' "0123456789012345678901234567890123456789"
        ;;
    *"status --porcelain"*)
        [[ "${WHEEL_SLOT_TEST_DIRTY:-0}" == 0 ]] \
            || printf '%s\n' "?? private-account-filename"
        ;;
    *)
        exit 64
        ;;
esac
EOF

cat >"$fake_bin/swift" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$WHEEL_SLOT_TEST_LOG"
EOF
chmod +x "$fake_bin/git" "$fake_bin/swift"

assert_failure() {
    local expected="$1"
    shift
    local output
    if output="$({ "$@"; } 2>&1)"; then
        fail "invalid slot invocation unexpectedly passed"
    fi
    [[ "$output" == "SPIKE-001 physical slot FAILED: $expected" ]] \
        || fail "slot runner emitted an unexpected diagnostic"
    [[ "$output" != *"$test_root"* && "$output" != *"private-account-filename"* ]] \
        || fail "slot runner exposed private filesystem data"
}

slots=(caps-lock-built-in caps-lock-external right-option-built-in right-option-external)
for slot in "${slots[@]}"; do
    summary="$test_root/$slot.json"
    PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
        bash "$script" "$slot" "$summary" \
        || fail "canonical slot failed"

    expected_trigger="right-option"
    [[ "$slot" == caps-lock-* ]] && expected_trigger="caps-lock"
    expected="run wheel-input-spike --trigger $expected_trigger --sequences 100 --label $slot --summary-json $summary"
    [[ "$(<"$invocation_log")" == "$expected" ]] \
        || fail "canonical slot arguments changed"
done

assert_failure "unsupported physical slot" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    bash "$script" private-device-name "$test_root/invalid.json"

assert_failure "summary destination must be outside the source checkout" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    bash "$script" caps-lock-built-in "$repo_root/private.json"

touch "$test_root/existing.json"
assert_failure "summary destination must not already exist" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    bash "$script" caps-lock-built-in "$test_root/existing.json"

assert_failure "source worktree must be clean before a physical slot" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    WHEEL_SLOT_TEST_DIRTY=1 \
    bash "$script" caps-lock-built-in "$test_root/dirty.json"

assert_failure "current source revision must equal the published branch head" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    WHEEL_SLOT_TEST_UPSTREAM=abcdefabcdefabcdefabcdefabcdefabcdefabcd \
    bash "$script" right-option-built-in "$test_root/diverged.json"

echo "SPIKE-001 physical slot tests PASS"
