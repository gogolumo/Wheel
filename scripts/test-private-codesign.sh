#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
test_root="$(mktemp -d)"
fake_bin="$test_root/bin"
invocation_log="$test_root/invocation"
private_identity="private-certificate-common-name"
private_app="$test_root/private-account/Wheel.app"
trap 'rm -rf "$test_root"' EXIT
mkdir -p "$fake_bin" "$private_app"

fail() {
    echo "Private codesign boundary tests FAILED: $1" >&2
    exit 1
}

cat >"$fake_bin/codesign" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$WHEEL_CODESIGN_TEST_LOG"
echo "codesign leaked arguments: $*" >&2
[[ "${WHEEL_CODESIGN_TEST_RESULT:-failure}" == success ]]
EOF
chmod +x "$fake_bin/codesign"

# shellcheck source=scripts/lib/private-codesign.sh
source "$repo_root/scripts/lib/private-codesign.sh"

output=""
if output="$(PATH="$fake_bin:$PATH" \
    WHEEL_CODESIGN_TEST_LOG="$invocation_log" \
    wheel_codesign_app "$private_identity" "$private_app" 2>&1)"; then
    fail "a failing codesign invocation unexpectedly passed"
fi
[[ -z "$output" ]] || fail "codesign diagnostics escaped the privacy boundary"
grep -Fq -- "$private_identity" "$invocation_log" \
    || fail "the signing identity was not passed to codesign"
grep -Fq -- "$private_app" "$invocation_log" \
    || fail "the application path was not passed to codesign"

output="$(PATH="$fake_bin:$PATH" \
    WHEEL_CODESIGN_TEST_LOG="$invocation_log" \
    WHEEL_CODESIGN_TEST_RESULT=success \
    wheel_codesign_app "$private_identity" "$private_app" 2>&1)" \
    || fail "a successful codesign invocation failed"
[[ -z "$output" ]] || fail "successful codesign emitted private diagnostics"

if wheel_codesign_app only-one-argument >/dev/null 2>&1; then
    fail "invalid helper arguments unexpectedly passed"
fi

echo "Private codesign boundary tests PASS"
