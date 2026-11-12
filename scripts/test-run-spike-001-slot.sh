#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
script="$repo_root/scripts/run-spike-001-slot.sh"
test_root="$(mktemp -d)"
fake_bin="$test_root/bin"
invocation_log="$test_root/swift-invocation"
signed_build_evidence="$test_root/spike-001-signed-build.json"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$fake_bin"
printf '%s\n' '{}' >"$signed_build_evidence"

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
printf '%s\n' "$*" >>"$WHEEL_SLOT_TEST_LOG"
if [[ "$*" == *"run wheel-evidence-check --signed-build-only "* \
    && "${WHEEL_SLOT_TEST_POSTFLIGHT_SOURCE_FAILURE:-0}" == 1 ]]; then
    signed_checks="$(grep -c 'run wheel-evidence-check --signed-build-only ' "$WHEEL_SLOT_TEST_LOG")"
    [[ "$signed_checks" -lt 2 ]] || exit 1
fi
if [[ "$*" == *"run wheel-input-spike "* ]]; then
    summary=""
    previous=""
    for argument in "$@"; do
        if [[ "$previous" == "--summary-json" ]]; then
            summary="$argument"
            break
        fi
        previous="$argument"
    done
    [[ -n "$summary" ]]
    if [[ "${WHEEL_SLOT_TEST_SKIP_SUMMARY:-0}" == 0 ]]; then
        printf '%s\n' '{}' >"$summary"
    fi
    exit "${WHEEL_SLOT_TEST_CAPTURE_EXIT:-0}"
fi
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
    : >"$invocation_log"
    PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
        bash "$script" "$slot" "$summary" "$signed_build_evidence" \
        || fail "canonical slot failed"

    expected_trigger="right-option"
    expected_evidence_trigger="rightOption"
    [[ "$slot" == caps-lock-* ]] && expected_trigger="caps-lock"
    [[ "$slot" == caps-lock-* ]] && expected_evidence_trigger="capsLock"
    expected="run wheel-evidence-check --signed-build-only $signed_build_evidence
run wheel-input-spike --trigger $expected_trigger --sequences 100 --label $slot --summary-json $summary
run wheel-evidence-check --signed-build-only $signed_build_evidence
run wheel-evidence-check --require-run $slot $expected_evidence_trigger --expected-trigger $expected_trigger --expected-sequence-target 100 $summary"
    [[ "$(<"$invocation_log")" == "$expected" ]] \
        || fail "canonical slot arguments changed"
done

changed_source_summary="$test_root/changed-source.json"
: >"$invocation_log"
set +e
PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    WHEEL_SLOT_TEST_POSTFLIGHT_SOURCE_FAILURE=1 \
    bash "$script" caps-lock-built-in "$changed_source_summary" "$signed_build_evidence"
changed_source_exit=$?
set -e
[[ "$changed_source_exit" -ne 0 ]] \
    || fail "changed source during capture unexpectedly passed"
[[ "$(grep -c 'run wheel-evidence-check --signed-build-only ' "$invocation_log")" -eq 2 ]] \
    || fail "signed source was not checked before and after capture"
[[ "$(<"$invocation_log")" != *"run wheel-evidence-check --require-run"* ]] \
    || fail "changed source continued into evidence postflight"

missing_summary="$test_root/missing-summary.json"
assert_failure "input spike did not create evidence" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    WHEEL_SLOT_TEST_SKIP_SUMMARY=1 \
    bash "$script" caps-lock-built-in "$missing_summary" "$signed_build_evidence"

interrupted_summary="$test_root/interrupted.json"
: >"$invocation_log"
set +e
PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    WHEEL_SLOT_TEST_CAPTURE_EXIT=130 \
    bash "$script" right-option-external "$interrupted_summary" "$signed_build_evidence"
interrupted_exit=$?
set -e
[[ "$interrupted_exit" -eq 130 && -s "$interrupted_summary" ]] \
    || fail "interrupted physical slot did not preserve partial evidence status"
[[ "$(<"$invocation_log")" == *"run wheel-evidence-check --signed-build-only $signed_build_evidence"$'\n'"run wheel-evidence-check --require-run right-option-external"* ]] \
    || fail "interrupted physical slot skipped signed-source postflight"
[[ "$(<"$invocation_log")" == *"run wheel-evidence-check --require-run right-option-external rightOption --expected-trigger right-option --expected-sequence-target 100 $interrupted_summary" ]] \
    || fail "interrupted physical slot skipped evidence postflight"

assert_failure "unsupported physical slot" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    bash "$script" private-device-name "$test_root/invalid.json" "$signed_build_evidence"

assert_failure "summary destination must be outside the source checkout" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    bash "$script" caps-lock-built-in "$repo_root/private.json" "$signed_build_evidence"

touch "$test_root/existing.json"
assert_failure "summary destination must not already exist" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    bash "$script" caps-lock-built-in "$test_root/existing.json" "$signed_build_evidence"

assert_failure "signed-build evidence is unavailable" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    bash "$script" caps-lock-built-in "$test_root/missing-build.json" \
    "$test_root/missing-signed-build.json"

assert_failure "signed-build evidence must be outside the source checkout" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    bash "$script" caps-lock-built-in "$test_root/inside-build.json" \
    "$repo_root/Package.swift"

assert_failure "source worktree must be clean before a physical slot" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    WHEEL_SLOT_TEST_DIRTY=1 \
    bash "$script" caps-lock-built-in "$test_root/dirty.json" "$signed_build_evidence"

assert_failure "current source revision must equal the published branch head" \
    env PATH="$fake_bin:$PATH" WHEEL_SLOT_TEST_LOG="$invocation_log" \
    WHEEL_SLOT_TEST_UPSTREAM=abcdefabcdefabcdefabcdefabcdefabcdefabcd \
    bash "$script" right-option-built-in "$test_root/diverged.json" "$signed_build_evidence"

echo "SPIKE-001 physical slot tests PASS"
