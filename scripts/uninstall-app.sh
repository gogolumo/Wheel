#!/usr/bin/env bash
set -euo pipefail

app="${1:-/Applications/Wheel.app}"

fail() {
    echo "Wheel.app removal failed: $*" >&2
    exit 1
}

if [[ $# -gt 1 ]]; then
    fail "usage: scripts/uninstall-app.sh [app-path]"
fi

if [[ "$(uname -s)" != Darwin ]]; then
    fail "removal requires macOS 14 or newer"
fi

for command in pgrep codesign; do
    if ! command -v "$command" >/dev/null 2>&1; then
        fail "missing required macOS tool: $command"
    fi
done

plist_buddy="/usr/libexec/PlistBuddy"
[[ -x "$plist_buddy" ]] || fail "missing required macOS tool: $plist_buddy"
[[ "$app" = /* ]] || fail "application path must be absolute"
[[ "${app##*/}" == "Wheel.app" ]] || fail "application path must end in Wheel.app"

parent_input="$(dirname "$app")"
[[ -d "$parent_input" ]] || fail "application directory does not exist: $parent_input"
parent="$(cd "$parent_input" && pwd -P)"
app="$parent/Wheel.app"

[[ -e "$app" ]] || fail "Wheel.app is not installed at $app"
[[ -d "$app" ]] || fail "target is not an application bundle directory"
[[ ! -L "$app" ]] || fail "refusing to remove a symbolic-link target"

if pgrep -x Wheel >/dev/null 2>&1; then
    fail "Wheel is running; quit it from the menu bar before removing it"
fi

info_plist="$app/Contents/Info.plist"
executable="$app/Contents/MacOS/Wheel"
[[ -f "$info_plist" ]] || fail "target has no Contents/Info.plist"
[[ -x "$executable" ]] || fail "target has no executable Contents/MacOS/Wheel"
identifier="$("$plist_buddy" -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null)" \
    || fail "target has no CFBundleIdentifier"
[[ "$identifier" == "dev.gogolumo.Wheel" ]] \
    || fail "refusing to remove unrelated app with bundle id '$identifier'"
codesign --verify --deep --strict "$app" >/dev/null 2>&1 \
    || fail "target has an invalid code signature; remove it manually after inspection"

rm -rf "$app"
[[ ! -e "$app" ]] || fail "Wheel.app still exists after removal"

echo "Removed $app"
echo "Wheel application data was preserved in ~/Library/Application Support/Wheel."
