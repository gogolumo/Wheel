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
executable="$app/Contents/MacOS/Wheel"
icon="$app/Contents/Resources/Wheel.icns"
resource_bundle="$app/Contents/Resources/Wheel_WheelApp.bundle"
[[ -f "$info_plist" && ! -L "$info_plist" ]] \
    || fail "application metadata is unavailable"
[[ -f "$executable" && -x "$executable" && ! -L "$executable" ]] \
    || fail "application executable is unavailable"
[[ -f "$icon" && ! -L "$icon" ]] \
    || fail "application resources are unavailable"
[[ -d "$resource_bundle" && ! -L "$resource_bundle" ]] \
    || fail "application brand resources are unavailable"
brand_resources="$resource_bundle/Contents/Resources"
[[ -d "$brand_resources" ]] || brand_resources="$resource_bundle"
for resource in WheelSymbol.pdf WheelSymbolLight.pdf \
    WheelSymbolMonochromeBlack.pdf WheelSymbolMonochromeWhite.pdf \
    WheelMenuBarTemplate.pdf WheelAppIcon.png; do
    [[ -f "$brand_resources/$resource" && ! -L "$brand_resources/$resource" ]] \
        || fail "application brand resources are incomplete"
done

bundle_executable="$(plutil -extract CFBundleExecutable raw -o - "$info_plist" 2>/dev/null)" \
    || fail "application executable metadata is unavailable"
[[ "$bundle_executable" == Wheel ]] \
    || fail "application executable metadata is invalid"
bundle_identifier="$(plutil -extract CFBundleIdentifier raw -o - "$info_plist" 2>/dev/null)" \
    || fail "application identifier metadata is unavailable"
[[ "$bundle_identifier" == dev.gogolumo.Wheel ]] \
    || fail "application identifier metadata is invalid"

head_revision="$(git -C "$repo_root" rev-parse --verify HEAD 2>/dev/null)" \
    || fail "current source revision is unavailable"
[[ "$head_revision" =~ ^[0-9a-f]{40}$ ]] \
    || fail "current source revision is invalid"

if [[ -z "$expected_revision" ]]; then
    expected_revision="$head_revision"
fi
[[ "$expected_revision" =~ ^[0-9a-f]{40}$ ]] \
    || fail "expected source revision is invalid"
[[ "$expected_revision" == "$head_revision" ]] \
    || fail "expected source revision does not match the current checkout"

# Physical evidence must be reproducible from the published review branch, not
# only from a clean local commit. This deliberately relies on the fetched
# upstream ref; the protocol fetches and fast-forwards immediately beforehand.
upstream_revision="$(git -C "$repo_root" rev-parse --verify '@{upstream}' 2>/dev/null)" \
    || fail "a published upstream source revision is required"
[[ "$upstream_revision" =~ ^[0-9a-f]{40}$ ]] \
    || fail "published upstream source revision is invalid"
[[ "$upstream_revision" == "$expected_revision" ]] \
    || fail "tested source revision is not the published branch head"

# `build-app.sh` compiles the current checkout, not only committed files. A
# dirty checkout could therefore produce a bundle stamped with HEAD while its
# executable contains unreviewed source. Do not print porcelain output because
# filenames can contain private information.
worktree_status="$(git -C "$repo_root" status --porcelain --untracked-files=all 2>/dev/null)" \
    || fail "source worktree state is unavailable"
[[ -z "$worktree_status" ]] \
    || fail "source worktree must be clean before physical evidence"

bundle_revision="$(plutil -extract WheelSourceRevision raw -o - "$info_plist" 2>/dev/null)" \
    || fail "bundle source revision is unavailable"
[[ "$bundle_revision" =~ ^[0-9a-f]{40}$ ]] \
    || fail "bundle source revision is invalid"
[[ "$bundle_revision" == "$expected_revision" ]] \
    || fail "bundle source revision does not match the tested commit"

codesign --verify --deep --strict "$app" >/dev/null 2>&1 \
    || fail "code signature verification failed"

# A locally created self-signed certificate can produce a structurally valid,
# non-ad-hoc signature with an Authority field. SPIKE-001 requires an Apple-
# issued development or distribution identity, so validate the trust anchor
# without printing the certificate chain or Team ID.
codesign --verify --deep --strict \
    --test-requirement '=anchor apple generic and identifier "dev.gogolumo.Wheel"' \
    "$app" >/dev/null 2>&1 \
    || fail "an Apple-issued signing identity is required"

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
