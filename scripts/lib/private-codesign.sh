#!/usr/bin/env bash

# Run the signing boundary without forwarding certificate/account details or
# local artifact paths from codesign diagnostics. Callers provide a generic,
# context-appropriate failure message.
wheel_codesign_app() {
    [[ $# -eq 2 ]] || return 64
    local signing_identity="$1"
    local app="$2"

    codesign --force --sign "$signing_identity" "$app" >/dev/null 2>&1
}
