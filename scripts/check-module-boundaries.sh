#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAIN_SOURCES="$ROOT/Sources/WheelDomain"

if [[ ! -d "$DOMAIN_SOURCES" ]]; then
    printf 'error: WheelDomain sources not found at %s\n' "$DOMAIN_SOURCES" >&2
    exit 1
fi

FORBIDDEN_IMPORTS='^[[:space:]]*import[[:space:]]+(AppKit|SwiftUI|ApplicationServices|CoreGraphics|CoreServices|Carbon)([[:space:]]|$)'

if grep -REn "$FORBIDDEN_IMPORTS" "$DOMAIN_SOURCES"; then
    printf '%s\n' 'error: WheelDomain must remain independent of macOS UI and input frameworks' >&2
    exit 1
elif [[ $? -ne 1 ]]; then
    printf '%s\n' 'error: unable to inspect WheelDomain imports' >&2
    exit 1
fi

printf '%s\n' 'Module boundary check PASS: WheelDomain is platform-independent'
