#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d)"
fake_bin="$test_root/bin"
mkdir -p "$fake_bin"

cleanup() {
    local status=$?
    trap - EXIT
    set +e
    rm -f "$fake_bin/pgrep" "$fake_bin/ps"
    rmdir "$fake_bin" "$test_root" 2>/dev/null
    exit "$status"
}
trap cleanup EXIT

cat >"$fake_bin/pgrep" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 101 202 303
EOF

cat >"$fake_bin/ps" <<'EOF'
#!/usr/bin/env bash
pid=""
while [[ $# -gt 0 ]]; do
    if [[ "$1" == "-p" ]]; then
        pid="$2"
        shift 2
    else
        shift
    fi
done
case "$pid" in
    101) printf '%s\n' '/tmp/unrelated/Wheel 300' ;;
    202) printf '   %s --fixture ready\n' "$WHEEL_TEST_EXPECTED_EXECUTABLE" ;;
    303) printf '%s\n' "$WHEEL_TEST_EXPECTED_EXECUTABLE" ;;
    *) exit 1 ;;
esac
EOF

chmod +x "$fake_bin/pgrep" "$fake_bin/ps"
export PATH="$fake_bin:$PATH"
export WHEEL_TEST_EXPECTED_EXECUTABLE="$test_root/Installed Apps/Wheel.app/Contents/MacOS/Wheel"
source "$repo_root/scripts/lib/app-process.sh"

found_pid="$(wheel_find_running_pid "$WHEEL_TEST_EXPECTED_EXECUTABLE")"
[[ "$found_pid" == 202 ]] \
    || { echo "process helper did not skip the unrelated same-name process" >&2; exit 1; }
wheel_process_matches_executable 202 "$WHEEL_TEST_EXPECTED_EXECUTABLE"
wheel_process_matches_executable 303 "$WHEEL_TEST_EXPECTED_EXECUTABLE"
if wheel_process_matches_executable 101 "$WHEEL_TEST_EXPECTED_EXECUTABLE"; then
    echo "process helper accepted an unrelated same-name process" >&2
    exit 1
fi
if wheel_process_matches_executable 202 "$WHEEL_TEST_EXPECTED_EXECUTABLE-other"; then
    echo "process helper accepted a different executable path" >&2
    exit 1
fi
if wheel_find_running_pid "$WHEEL_TEST_EXPECTED_EXECUTABLE-other" >/dev/null; then
    echo "process helper found a process for a different executable path" >&2
    exit 1
fi
if wheel_process_matches_executable not-a-pid "$WHEEL_TEST_EXPECTED_EXECUTABLE"; then
    echo "process helper accepted a nonnumeric PID" >&2
    exit 1
fi

echo "Wheel process ownership helper PASS"
