#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
fake_bin="$test_root/bin"
app="$test_root/private-account/Wheel.app"
mkdir -p "$fake_bin" "$app"

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

chmod +x "$fake_bin/uname" "$fake_bin/codesign"

run_verifier() {
    PATH="$fake_bin:$PATH" \
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

failure_output="$(WHEEL_TEST_SIGNATURE_LINE=Signature=adhoc run_verifier || true)"
[[ "$failure_output" != *"$test_root"* ]]
[[ "$failure_output" != *"Private Identity"* ]]
[[ "$failure_output" != *"PRIVATE123"* ]]

echo "SPIKE-001 signed-build verifier tests PASS"
