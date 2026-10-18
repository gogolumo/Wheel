#!/usr/bin/env bash
set -euo pipefail

# Verify only the SPIKE-001 signed-build precondition. Keep certificate
# identities, Team IDs, and local filesystem paths out of stdout/stderr.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:-$repo_root/dist/Wheel.app}"
expected_revision="${2:-}"

fail() {
    echo "SPIKE-001 signed-build evidence FAILED: $1" >&2
    exit 1
}

[[ $# -le 2 ]] || fail "expected an optional application and source revision"
[[ "$(uname -s)" == Darwin ]] || fail "verification requires macOS"
for command in codesign git plutil; do
    command -v "$command" >/dev/null 2>&1 || fail "a required macOS tool is unavailable"
done
[[ -d "$app" && ! -L "$app" ]] || fail "application bundle is unavailable"

info_plist="$app/Contents/Info.plist"
[[ -f "$info_plist" && ! -L "$info_plist" ]] \
    || fail "application metadata is unavailable"

if [[ -z "$expected_revision" ]]; then
    expected_revision="$(git -C "$repo_root" rev-parse --verify HEAD 2>/dev/null)" \
        || fail "expected source revision is unavailable"
fi
[[ "$expected_revision" =~ ^[0-9a-f]{40}$ ]] \
    || fail "expected source revision is invalid"

bundle_revision="$(plutil -extract WheelSourceRevision raw -o - "$info_plist" 2>/dev/null)" \
    || fail "bundle source revision is unavailable"
[[ "$bundle_revision" =~ ^[0-9a-f]{40}$ ]] \
    || fail "bundle source revision is invalid"
[[ "$bundle_revision" == "$expected_revision" ]] \
    || fail "bundle source revision does not match the tested commit"

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
