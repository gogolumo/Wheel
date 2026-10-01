#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

printf 'Wheel M0 bootstrap check\n'
printf 'Repository: %s\n' "$ROOT"

command -v swift >/dev/null || { echo 'error: swift is required' >&2; exit 1; }

printf '\n[1/4] swift build (warnings as errors)\n'
swift build -Xswiftc -warnings-as-errors

printf '\n[2/4] release build (warnings as errors)\n'
swift build -c release -Xswiftc -warnings-as-errors

printf '\n[3/4] swift test (warnings as errors)\n'
swift test -Xswiftc -warnings-as-errors

printf '\n[4/4] wheel-demo (warnings as errors)\n'
swift run -Xswiftc -warnings-as-errors wheel-demo

printf '\nM0 bootstrap check PASS\n'
