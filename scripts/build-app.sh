#!/usr/bin/env bash
set -euo pipefail

# Package the existing SwiftPM executable as a Launch Services application.
# An ad-hoc signature makes local builds internally consistent; distribution
# requires a Developer ID signature and notarization in a separate release step.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_dir="${1:-$repo_root/dist}"
signing_identity="${WHEEL_CODESIGN_IDENTITY:--}"
source "$repo_root/scripts/lib/app-process.sh"

fail() {
    echo "Wheel.app build failed: $*" >&2
    exit 1
}

if [[ $# -gt 1 ]]; then
    fail "usage: scripts/build-app.sh [output-directory]"
fi

if [[ "$(uname -s)" != Darwin ]]; then
    fail "packaging requires macOS 14 or newer"
fi

for command in swift git sips iconutil plutil codesign pgrep ps; do
    if ! command -v "$command" >/dev/null 2>&1; then
        fail "missing required macOS tool: $command"
    fi
done

source_revision="${WHEEL_SOURCE_REVISION:-$(git -C "$repo_root" rev-parse --verify HEAD)}"
if [[ ! "$source_revision" =~ ^[0-9a-fA-F]{40}$ ]]; then
    fail "invalid Wheel source revision: $source_revision"
fi

mkdir -p "$output_dir"
output_dir="$(cd "$output_dir" && pwd -P)"
[[ -w "$output_dir" ]] || fail "output directory is not writable: $output_dir"

app="$output_dir/Wheel.app"
lock_dir="$output_dir/.wheel-build.lock"
transaction_root=""
staging_root=""
backup_app=""
rollback_required=0
lock_acquired=0

cleanup() {
    local status=$?
    local rollback_failed=0
    trap - EXIT
    set +e

    if [[ $status -ne 0 && $rollback_required -eq 1 ]]; then
        if [[ -e "$app" ]]; then
            mv "$app" "$transaction_root/failed-Wheel.app" \
                || rollback_failed=1
        fi
        if [[ -e "$backup_app" && ! -e "$app" ]]; then
            if mv "$backup_app" "$app"; then
                echo "Restored the previous Wheel.app after a build failure." >&2
            else
                rollback_failed=1
            fi
        elif [[ -e "$backup_app" ]]; then
            rollback_failed=1
        fi
    fi

    if [[ -n "$transaction_root" ]]; then
        if [[ $rollback_failed -eq 0 ]]; then
            rm -rf "$transaction_root"
        else
            echo "Automatic rollback was incomplete; recovery files remain at $transaction_root" >&2
            status=1
        fi
    fi

    if [[ $lock_acquired -eq 1 ]] && ! rmdir "$lock_dir" 2>/dev/null; then
        echo "Could not release build lock at $lock_dir" >&2
        status=1
    fi
    exit "$status"
}
trap cleanup EXIT

if ! mkdir "$lock_dir" 2>/dev/null; then
    fail "another Wheel.app build is already in progress for $output_dir"
fi
lock_acquired=1

[[ ! -L "$app" ]] || fail "refusing to replace a symbolic-link output bundle"
if [[ -e "$app" ]]; then
    [[ -d "$app" ]] || fail "output exists but is not an application bundle directory"
    bash "$repo_root/scripts/verify-app.sh" "$app" \
        || fail "existing output is not a verified Wheel.app; inspect or remove it manually"
fi

running_pid="$(wheel_find_running_pid "$app/Contents/MacOS/Wheel" || true)"
[[ -z "$running_pid" ]] \
    || fail "the output Wheel.app is running; quit it before rebuilding"

cd "$repo_root"
swift build --configuration release --product wheel-app
bin_dir="$(swift build --configuration release --show-bin-path)"
executable="$bin_dir/wheel-app"
if [[ ! -x "$executable" ]]; then
    fail "SwiftPM did not produce $executable"
fi

transaction_root="$(mktemp -d "$output_dir/.wheel-build.XXXXXX")"
staging_root="$transaction_root/staging"
backup_root="$transaction_root/backup"
staged_app="$staging_root/Wheel.app"
backup_app="$backup_root/Wheel.app"
mkdir -p "$staged_app/Contents/MacOS" "$staged_app/Contents/Resources" "$backup_root"
cp "$executable" "$staged_app/Contents/MacOS/Wheel"
cp packaging/Info.plist "$staged_app/Contents/Info.plist"
plutil -replace WheelSourceRevision -string "$source_revision" "$staged_app/Contents/Info.plist"
plutil -lint "$staged_app/Contents/Info.plist"

iconset="$transaction_root/Wheel.iconset"
mkdir -p "$iconset"
source_icon="$repo_root/packaging/Wheel-icon.png"
for size in 16 32 128 256 512; do
    sips -s format png -z "$size" "$size" "$source_icon" \
        --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double_size=$((size * 2))
    sips -s format png -z "$double_size" "$double_size" "$source_icon" \
        --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$staged_app/Contents/Resources/Wheel.icns"

codesign --force --sign "$signing_identity" "$staged_app"
bash "$repo_root/scripts/verify-app.sh" "$staged_app"

# Recheck immediately before replacement so a bundle launched during the
# release build is not silently swapped underneath a running process.
running_pid="$(wheel_find_running_pid "$app/Contents/MacOS/Wheel" || true)"
[[ -z "$running_pid" ]] \
    || fail "the output Wheel.app started during the build; quit it and retry"

rollback_required=1
if [[ -e "$app" ]]; then
    mv "$app" "$backup_app"
fi
mv "$staged_app" "$app"
bash "$repo_root/scripts/verify-app.sh" "$app"
rollback_required=0

echo "Built $app"
