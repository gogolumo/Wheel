#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:-/Applications/Wheel.app}"

fail() {
    echo "Wheel.app doctor failed: $*" >&2
    exit 1
}

if [[ $# -gt 1 ]]; then
    fail "usage: scripts/doctor-app.sh [app-path]"
fi

if [[ "$(uname -s)" != Darwin ]]; then
    fail "diagnostics require macOS 14 or newer"
fi

plist_buddy="/usr/libexec/PlistBuddy"
[[ -x "$plist_buddy" ]] || fail "missing required macOS tool: $plist_buddy"

bash "$repo_root/scripts/verify-app.sh" "$app"

info_plist="$app/Contents/Info.plist"
plist_value() {
    "$plist_buddy" -c "Print :$1" "$info_plist" 2>/dev/null
}

bundle_identifier="$(plist_value CFBundleIdentifier)"
short_version="$(plist_value CFBundleShortVersionString)"
build_version="$(plist_value CFBundleVersion)"
source_revision="$(plist_value WheelSourceRevision)"

echo "Wheel.app doctor"
echo "Bundle: $app"
echo "Bundle contract: PASS"
echo "Bundle identifier: $bundle_identifier"
echo "Version: $short_version ($build_version)"
echo "Source revision: $source_revision"
echo "Signature identifier: dev.gogolumo.Wheel"

if command -v mdls >/dev/null 2>&1; then
    spotlight_identifier="$(mdls -name kMDItemCFBundleIdentifier -raw "$app" 2>/dev/null || true)"
    if [[ "$spotlight_identifier" == "$bundle_identifier" ]]; then
        echo "Spotlight metadata: PASS ($spotlight_identifier)"
    else
        echo "Spotlight metadata: PENDING/UNAVAILABLE (${spotlight_identifier:-no value})"
    fi
else
    echo "Spotlight metadata: UNAVAILABLE (mdls missing)"
fi

if command -v pgrep >/dev/null 2>&1 && pgrep -x Wheel >/dev/null 2>&1; then
    echo "Running process: YES"
else
    echo "Running process: NO"
fi
