#!/usr/bin/env bash
set -euo pipefail

# Install or update a locally built Wheel.app without copying a second bundle
# inside an existing /Applications/Wheel.app directory.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_app="${1:-$repo_root/dist/Wheel.app}"
target_app="${2:-/Applications/Wheel.app}"

fail() {
    echo "Wheel.app installation failed: $*" >&2
    exit 1
}

if [[ $# -gt 2 ]]; then
    fail "usage: scripts/install-app.sh [source-app] [target-app]"
fi

if [[ "$(uname -s)" != Darwin ]]; then
    fail "installation requires macOS 14 or newer"
fi

for command in ditto pgrep; do
    if ! command -v "$command" >/dev/null 2>&1; then
        fail "missing required macOS tool: $command"
    fi
done

[[ -d "$source_app" ]] || fail "source bundle not found at $source_app"
[[ ! -L "$source_app" ]] || fail "source bundle must not be a symbolic link"
[[ "$target_app" = /* ]] || fail "target path must be absolute"
[[ "${target_app##*/}" == "Wheel.app" ]] || fail "target must end in Wheel.app"

source_parent="$(cd "$(dirname "$source_app")" && pwd -P)"
source_app="$source_parent/$(basename "$source_app")"
target_parent_input="$(dirname "$target_app")"
[[ -d "$target_parent_input" ]] || fail "target directory does not exist: $target_parent_input"
target_parent="$(cd "$target_parent_input" && pwd -P)"
target_app="$target_parent/Wheel.app"

[[ "$source_app" != "$target_app" ]] || fail "source and target bundle are the same path"
[[ -w "$target_parent" ]] \
    || fail "$target_parent is not writable; rerun the installer with appropriate privileges"
[[ ! -L "$target_app" ]] || fail "refusing to replace a symbolic-link target"
if [[ -e "$target_app" && ! -d "$target_app" ]]; then
    fail "target exists but is not an application bundle directory"
fi

if pgrep -x Wheel >/dev/null 2>&1; then
    fail "Wheel is running; quit it from the menu bar before installing an update"
fi

bash "$repo_root/scripts/verify-app.sh" "$source_app"

transaction_root="$(mktemp -d "$target_parent/.wheel-install.XXXXXX")"
staging_root="$transaction_root/staging"
backup_root="$transaction_root/backup"
mkdir -p "$staging_root" "$backup_root"
staged_app="$staging_root/Wheel.app"
backup_app="$backup_root/Wheel.app"
rollback_required=0

cleanup() {
    local status=$?
    local rollback_failed=0
    trap - EXIT
    set +e

    if [[ $status -ne 0 && $rollback_required -eq 1 ]]; then
        if [[ -e "$target_app" ]]; then
            mv "$target_app" "$staging_root/failed-Wheel.app" \
                || rollback_failed=1
        fi
        if [[ -e "$backup_app" && ! -e "$target_app" ]]; then
            if mv "$backup_app" "$target_app"; then
                echo "Restored the previous Wheel.app after an installation failure." >&2
            else
                rollback_failed=1
            fi
        elif [[ -e "$backup_app" ]]; then
            rollback_failed=1
        fi
    fi

    if [[ $rollback_failed -eq 0 ]]; then
        rm -rf "$transaction_root"
    else
        echo "Automatic rollback was incomplete; recovery files remain at $transaction_root" >&2
        status=1
    fi
    exit "$status"
}
trap cleanup EXIT

ditto --rsrc --extattr "$source_app" "$staged_app"
bash "$repo_root/scripts/verify-app.sh" "$staged_app"

rollback_required=1
if [[ -e "$target_app" ]]; then
    mv "$target_app" "$backup_app"
fi
mv "$staged_app" "$target_app"
bash "$repo_root/scripts/verify-app.sh" "$target_app"
rollback_required=0

echo "Installed $target_app"
echo "Launch it with: open \"$target_app\""
