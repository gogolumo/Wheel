#!/usr/bin/env bash
set -euo pipefail

# Verify only the SPIKE-001 signed-build precondition. Keep certificate
# identities, Team IDs, and local filesystem paths out of stdout/stderr.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:-$repo_root/dist/Wheel.app}"

fail() {
    echo "SPIKE-001 signed-build evidence FAILED: $1" >&2
    exit 1
}

[[ $# -le 1 ]] || fail "expected zero or one application argument"
[[ "$(uname -s)" == Darwin ]] || fail "verification requires macOS"
command -v codesign >/dev/null 2>&1 || fail "codesign is unavailable"
[[ -d "$app" && ! -L "$app" ]] || fail "application bundle is unavailable"

codesign --verify --deep --strict "$app" >/dev/null 2>&1 \
    || fail "code signature verification failed"

signature_details="$(codesign -dv --verbose=4 "$app" 2>&1)" \
    || fail "code signature metadata is unavailable"
grep -Fqx "Identifier=dev.gogolumo.Wheel" <<<"$signature_details" \
    || fail "code signature identifier is invalid"
if grep -Fqx "Signature=adhoc" <<<"$signature_details"; then
    fail "ad-hoc signatures do not satisfy the physical spike"
fi
grep -Fq "Authority=" <<<"$signature_details" \
    || fail "a signing authority is required"

echo "SPIKE-001 signed-build evidence PASS"
