#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
runbook="$repo_root/docs/SPIKE-001-FINAL-EVIDENCE.md"

fail() {
    echo "SPIKE-001 runbook contract FAILED: $1" >&2
    exit 1
}

required_text=(
    "fix/SPIKE-001-signed-build-evidence"
    "scripts/prepare-spike-001-physical.sh"
    "--profile spike-001-final"
    "--signed-build-evidence ../spike-001-signed-build.json"
    "--recording-duration-seconds 120"
    "--attempt-count caps-lock-built-in 100"
    "--attempt-count caps-lock-external 100"
    "--attempt-count right-option-built-in 100"
    "--attempt-count right-option-external 100"
    "../caps-lock-built-in.json"
    "../caps-lock-external.json"
    "../right-option-built-in.json"
    "../right-option-external.json"
)

for text in "${required_text[@]}"; do
    grep -Fq -- "$text" "$runbook" \
        || fail "canonical physical handoff is incomplete"
done

for stale_text in "spike/GH-1-global-input-capture" "/tmp/wheel-spike-001-final.json"; do
    if grep -Fq -- "$stale_text" "$runbook"; then
        fail "stale physical handoff returned"
    fi
done

echo "SPIKE-001 runbook contract PASS"
