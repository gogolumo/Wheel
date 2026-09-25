#!/usr/bin/env bash
set -euo pipefail

# Package the existing SwiftPM executable as a Launch Services application.
# An ad-hoc signature makes local builds internally consistent; distribution
# requires a Developer ID signature and notarization in a separate release step.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$repo_root/dist}"
signing_identity="${WHEEL_CODESIGN_IDENTITY:--}"

if [[ "$(uname -s)" != Darwin ]]; then
    echo "Wheel.app must be built on macOS 14 or newer." >&2
    exit 1
fi

for command in swift sips iconutil plutil codesign; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Missing required macOS tool: $command" >&2
        exit 1
    fi
done

cd "$repo_root"
swift build --configuration release --product wheel-app
bin_dir="$(swift build --configuration release --show-bin-path)"
executable="$bin_dir/wheel-app"
if [[ ! -x "$executable" ]]; then
    echo "SwiftPM did not produce $executable" >&2
    exit 1
fi

mkdir -p "$output_dir"
app="$output_dir/Wheel.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$executable" "$app/Contents/MacOS/Wheel"
cp packaging/Info.plist "$app/Contents/Info.plist"
plutil -lint "$app/Contents/Info.plist"

iconset="$(mktemp -d "${TMPDIR:-/tmp}/wheel-icon.XXXXXX")/Wheel.iconset"
trap 'rm -rf "${iconset%/*}"' EXIT
mkdir -p "$iconset"
source_icon="$repo_root/packaging/Wheel-icon.png"
for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$source_icon" \
        --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -s format png -z "$double_size" "$double_size" "$source_icon" \
        --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app/Contents/Resources/Wheel.icns"

codesign --force --sign "$signing_identity" "$app"
codesign --verify --deep --strict --verbose=2 "$app"
echo "Built $app"
