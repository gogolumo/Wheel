#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

printf 'Wheel M0 bootstrap check\n'
printf 'Repository: %s\n' "$ROOT"

command -v swift >/dev/null || { echo 'error: swift is required' >&2; exit 1; }

printf '\n[1/3] swift build\n'
swift build

printf '\n[2/3] swift test\n'
swift test

printf '\n[3/3] wheel-demo\n'
swift run wheel-demo

printf '\nM0 bootstrap check PASS\n'
