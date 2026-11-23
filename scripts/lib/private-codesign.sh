#!/usr/bin/env bash

# Run the signing boundary without forwarding certificate/account details or
# local artifact paths from codesign diagnostics. Callers provide a generic,
# context-appropriate failure message.
wheel_codesign_path() {
    [[ $# -eq 2 || $# -eq 3 ]] || return 64
    local signing_identity="$1"
    local path="$2"
    local identifier="${3:-}"

    if [[ -n "$identifier" ]]; then
        codesign --force --identifier "$identifier" \
            --sign "$signing_identity" "$path" >/dev/null 2>&1
    else
        codesign --force --sign "$signing_identity" "$path" >/dev/null 2>&1
    fi
}

wheel_codesign_app() {
    wheel_codesign_path "$@"
}
