#!/usr/bin/env bash
set -euo pipefail

# Launch an already verified Wheel.app through Launch Services in deterministic
# fixture mode. This proves that the packaged executable can be resolved and
# remains alive without requesting Input Monitoring. It does not replace the
# visible Finder/menu-bar/TCC checks that require a real user session.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${1:-/Applications/Wheel.app}"
source "$repo_root/scripts/lib/app-process.sh"

fail() {
    echo "Wheel.app launch smoke failed: $*" >&2
    exit 1
}

if [[ $# -gt 1 ]]; then
    fail "usage: scripts/smoke-app.sh [app-path]"
fi

if [[ "$(uname -s)" != Darwin ]]; then
    fail "launch smoke requires macOS 14 or newer"
fi

for command in open pgrep ps; do
    if ! command -v "$command" >/dev/null 2>&1; then
        fail "missing required macOS tool: $command"
    fi
done

bash "$repo_root/scripts/verify-app.sh" "$app"

app_parent="$(cd "$(dirname "$app")" && pwd -P)"
app="$app_parent/$(basename "$app")"
expected_executable="$app/Contents/MacOS/Wheel"

running_pid="$(wheel_find_running_pid "$expected_executable" || true)"
[[ -z "$running_pid" ]] \
    || fail "this Wheel.app is already running; quit it before the launch smoke"

launcher_pid=""
wheel_pid=""

cleanup() {
    local status=$?
    trap - EXIT INT TERM
    set +e

    if [[ -n "$wheel_pid" ]] \
        && kill -0 "$wheel_pid" >/dev/null 2>&1 \
        && wheel_process_matches_executable "$wheel_pid" "$expected_executable"; then
        kill -TERM "$wheel_pid" >/dev/null 2>&1
        for ((attempt = 0; attempt < 50; attempt += 1)); do
            kill -0 "$wheel_pid" >/dev/null 2>&1 || break
            sleep 0.1
        done
        if kill -0 "$wheel_pid" >/dev/null 2>&1 \
            && wheel_process_matches_executable "$wheel_pid" "$expected_executable"; then
            kill -KILL "$wheel_pid" >/dev/null 2>&1
        fi
    fi

    if [[ -n "$launcher_pid" ]] && kill -0 "$launcher_pid" >/dev/null 2>&1; then
        kill -TERM "$launcher_pid" >/dev/null 2>&1
    fi
    [[ -z "$launcher_pid" ]] || wait "$launcher_pid" >/dev/null 2>&1

    exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

open -n -W "$app" --args --fixture ready &
launcher_pid=$!

for ((attempt = 0; attempt < 100; attempt += 1)); do
    wheel_pid="$(wheel_find_running_pid "$expected_executable" || true)"
    if [[ -n "$wheel_pid" ]]; then
        break
    fi
    if ! kill -0 "$launcher_pid" >/dev/null 2>&1; then
        wait "$launcher_pid" || true
        fail "Launch Services exited before Wheel started"
    fi
    sleep 0.1
done

[[ -n "$wheel_pid" ]] || fail "Wheel did not start within 10 seconds"

wheel_process_matches_executable "$wheel_pid" "$expected_executable" \
    || fail "the launched Wheel process no longer matches the installed executable"

sleep 1
kill -0 "$wheel_pid" >/dev/null 2>&1 \
    || fail "Wheel exited during the launch stability check"

echo "Launch smoke PASS: $expected_executable stayed alive in fixture mode"
