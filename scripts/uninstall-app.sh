#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

command -v pgrep >/dev/null 2>&1 || fail "missing required macOS tool: pgrep"

[[ "$app" = /* ]] || fail "application path must be absolute"
[[ "${app##*/}" == "Wheel.app" ]] || fail "application path must end in Wheel.app"

parent_input="$(dirname "$app")"
[[ -d "$parent_input" ]] || fail "application directory does not exist: $parent_input"
parent="$(cd "$parent_input" && pwd -P)"
app="$parent/Wheel.app"

lock_dir="$parent/.wheel-install.lock"
lock_acquired=0

cleanup() {
    local status=$?
    trap - EXIT
    set +e

    if [[ $lock_acquired -eq 1 ]] && ! rmdir "$lock_dir" 2>/dev/null; then
        echo "Could not release installer lock at $lock_dir" >&2
        status=1
    fi
    exit "$status"
}
trap cleanup EXIT

if ! mkdir "$lock_dir" 2>/dev/null; then
    fail "another Wheel installation or removal is already in progress for $parent"
fi
lock_acquired=1

[[ -e "$app" ]] || fail "Wheel.app is not installed at $app"
[[ -d "$app" ]] || fail "target is not an application bundle directory"
[[ ! -L "$app" ]] || fail "refusing to remove a symbolic-link target"

if pgrep -x Wheel >/dev/null 2>&1; then
    fail "Wheel is running; quit it from the menu bar before removing it"
fi

# Deletion is irreversible, so require the same complete bundle contract used
# by build and install rather than trusting only a matching bundle identifier.
bash "$repo_root/scripts/verify-app.sh" "$app" \
    || fail "target is not a verified Wheel.app; inspect or remove it manually"

rm -rf "$app"
[[ ! -e "$app" ]] || fail "Wheel.app still exists after removal"

echo "Removed $app"
echo "Wheel application data was preserved in ~/Library/Application Support/Wheel."
