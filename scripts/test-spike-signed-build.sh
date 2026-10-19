#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
fake_bin="$test_root/bin"
app="$test_root/private-account/Wheel.app"
info_plist="$app/Contents/Info.plist"
expected_revision="0123456789abcdef0123456789abcdef01234567"
mkdir -p "$fake_bin" "$(dirname "$info_plist")"
: >"$info_plist"

cleanup() {
    local status=$?
    trap - EXIT
    rm -rf "$test_root"
    exit "$status"
}
trap cleanup EXIT

cat >"$fake_bin/uname" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' Darwin
EOF

cat >"$fake_bin/codesign" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "--verify" ]]; then
    [[ "${WHEEL_TEST_SIGNATURE_MODE:-valid}" != invalid ]]
    exit
fi
cat >&2 <<DETAILS
Identifier=dev.gogolumo.Wheel
${WHEEL_TEST_SIGNATURE_LINE:-Authority=Apple Development: Private Identity}
TeamIdentifier=PRIVATE123
DETAILS
EOF

cat >"$fake_bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" status "* ]]; then
    printf '%s' "${WHEEL_TEST_WORKTREE_STATUS:-}"
else
    printf '%s\n' "${WHEEL_TEST_GIT_REVISION:?}"
fi
EOF

cat >"$fake_bin/plutil" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${WHEEL_TEST_BUNDLE_REVISION:?}"
EOF

chmod +x "$fake_bin/uname" "$fake_bin/codesign" "$fake_bin/git" "$fake_bin/plutil"

run_verifier() {
    PATH="$fake_bin:/usr/bin:/bin" \
        WHEEL_TEST_GIT_REVISION="$expected_revision" \
        WHEEL_TEST_BUNDLE_REVISION="${1:-$expected_revision}" \
        bash "$repo_root/scripts/verify-spike-signed-build.sh" "$app" 2>&1
}

output="$(run_verifier)"
[[ "$output" == "SPIKE-001 signed-build evidence PASS" ]]

if WHEEL_TEST_SIGNATURE_LINE=Signature=adhoc run_verifier >/dev/null; then
    echo "signed-build verifier accepted an ad-hoc signature" >&2
    exit 1
fi

if WHEEL_TEST_SIGNATURE_MODE=invalid run_verifier >/dev/null; then
    echo "signed-build verifier accepted an invalid signature" >&2
    exit 1
fi

stale_revision="fedcba9876543210fedcba9876543210fedcba98"
if stale_output="$(run_verifier "$stale_revision")"; then
    echo "signed-build verifier accepted a stale source revision" >&2
    exit 1
fi

if invalid_revision_output="$(PATH="$fake_bin:/usr/bin:/bin" \
    WHEEL_TEST_SIGNATURE_MODE=valid \
    WHEEL_TEST_GIT_REVISION="$expected_revision" \
    WHEEL_TEST_BUNDLE_REVISION="$expected_revision" \
    bash "$repo_root/scripts/verify-spike-signed-build.sh" "$app" private-revision 2>&1)"; then
    echo "signed-build verifier accepted an invalid expected revision" >&2
    exit 1
fi

if dirty_output="$(WHEEL_TEST_WORKTREE_STATUS='?? private-filename.swift' run_verifier)"; then
    echo "signed-build verifier accepted a dirty source worktree" >&2
    exit 1
fi

failure_output="$(WHEEL_TEST_SIGNATURE_LINE=Signature=adhoc run_verifier || true)"
[[ "$failure_output" != *"$test_root"* ]]
[[ "$failure_output" != *"Private Identity"* ]]
[[ "$failure_output" != *"PRIVATE123"* ]]
[[ "$stale_output" != *"$expected_revision"* ]]
[[ "$stale_output" != *"$stale_revision"* ]]
[[ "$invalid_revision_output" != *"private-revision"* ]]
[[ "$dirty_output" != *"private-filename.swift"* ]]

echo "SPIKE-001 signed-build verifier tests PASS"
