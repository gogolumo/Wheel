#!/usr/bin/env bash
set -euo pipefail

# Verify the local-alpha bundle contract independently of the build step. This
# script intentionally does not use spctl: ad-hoc builds are not notarized and
# therefore are not expected to pass a public-distribution assessment.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:-$repo_root/dist/Wheel.app}"

fail() {
    echo "Wheel.app verification failed: $*" >&2
    exit 1
}

if [[ "$(uname -s)" != Darwin ]]; then
    fail "bundle verification requires macOS 14 or newer"
fi

for command in plutil codesign grep; do
    if ! command -v "$command" >/dev/null 2>&1; then
        fail "missing required macOS tool: $command"
    fi
done

plist_buddy="/usr/libexec/PlistBuddy"
[[ -x "$plist_buddy" ]] || fail "missing required macOS tool: $plist_buddy"
[[ -d "$app" ]] || fail "bundle not found at $app"
[[ ! -L "$app" ]] || fail "bundle path must not be a symbolic link"
[[ ! -e "$app/Wheel.app" ]] || fail "nested Wheel.app detected; use scripts/install-app.sh for updates"

info_plist="$app/Contents/Info.plist"
executable="$app/Contents/MacOS/Wheel"
icon="$app/Contents/Resources/Wheel.icns"

[[ -f "$info_plist" ]] || fail "missing Contents/Info.plist"
[[ -x "$executable" ]] || fail "missing executable Contents/MacOS/Wheel"
[[ -f "$icon" ]] || fail "missing Contents/Resources/Wheel.icns"

plutil -lint "$info_plist" >/dev/null

plist_value() {
    "$plist_buddy" -c "Print :$1" "$info_plist" 2>/dev/null
}

expect_plist_value() {
    local key="$1"
    local expected="$2"
    local actual
    actual="$(plist_value "$key")" || fail "missing Info.plist key $key"
    [[ "$actual" == "$expected" ]] \
        || fail "Info.plist $key is '$actual'; expected '$expected'"
}

expect_plist_value CFBundleExecutable Wheel
expect_plist_value CFBundleIdentifier dev.gogolumo.Wheel
expect_plist_value CFBundleInfoDictionaryVersion 6.0
expect_plist_value CFBundleName Wheel
expect_plist_value CFBundleDisplayName Wheel
expect_plist_value CFBundlePackageType APPL
expect_plist_value CFBundleIconFile Wheel.icns
expect_plist_value LSMinimumSystemVersion 14.0
expect_plist_value LSUIElement true
expect_plist_value NSHighResolutionCapable true

short_version="$(plist_value CFBundleShortVersionString)" \
    || fail "missing Info.plist key CFBundleShortVersionString"
build_version="$(plist_value CFBundleVersion)" \
    || fail "missing Info.plist key CFBundleVersion"
[[ "$short_version" =~ ^[0-9]+([.][0-9]+){1,2}$ ]] \
    || fail "invalid CFBundleShortVersionString '$short_version'"
[[ "$build_version" =~ ^[0-9]+([.][0-9]+)*$ ]] \
    || fail "invalid CFBundleVersion '$build_version'"

source_revision="$(plist_value WheelSourceRevision)" \
    || fail "missing Info.plist key WheelSourceRevision"
[[ "$source_revision" =~ ^[0-9a-fA-F]{40}$ ]] \
    || fail "invalid WheelSourceRevision '$source_revision'"

codesign --verify --deep --strict --verbose=2 "$app"
signature_details="$(codesign -dv --verbose=4 "$app" 2>&1)"
grep -Fq "Identifier=dev.gogolumo.Wheel" <<<"$signature_details" \
    || fail "code signature identifier does not match dev.gogolumo.Wheel"
echo "Verified $app"
