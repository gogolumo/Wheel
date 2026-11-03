#!/usr/bin/env bash
set -euo pipefail

# Build and attest the exact published SPIKE-001 checkout before physical use.
# Keep the evidence file outside the checkout so it cannot make the source tree
# dirty and invalidate its own signed-build attestation.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
    echo "SPIKE-001 physical preparation FAILED: $1" >&2
    exit 1
}

if [[ $# -gt 1 ]]; then
    fail "expected an optional summary destination"
fi

summary_json="${1:-$repo_root/../spike-001-signed-build.json}"
summary_dir="$(dirname "$summary_json")"
summary_name="$(basename "$summary_json")"
[[ -n "$summary_name" && "$summary_name" != "." && "$summary_name" != ".." ]] \
    || fail "summary destination is invalid"
[[ -d "$summary_dir" ]] || fail "summary destination directory is unavailable"
summary_dir="$(cd "$summary_dir" && pwd -P)" \
    || fail "summary destination directory is unavailable"
summary_json="$summary_dir/$summary_name"

case "$summary_json" in
    "$repo_root"|"$repo_root"/*)
        fail "summary destination must be outside the source checkout"
        ;;
esac
[[ ! -e "$summary_json" && ! -L "$summary_json" ]] \
    || fail "summary destination must not already exist"

[[ -n "${WHEEL_CODESIGN_IDENTITY:-}" ]] \
    || fail "WHEEL_CODESIGN_IDENTITY is required"

head_revision="$(git -C "$repo_root" rev-parse --verify HEAD 2>/dev/null)" \
    || fail "current source revision is unavailable"
upstream_revision="$(git -C "$repo_root" rev-parse --verify '@{upstream}' 2>/dev/null)" \
    || fail "a published upstream source revision is required"
[[ "$head_revision" == "$upstream_revision" ]] \
    || fail "current source revision must equal the published branch head"

# Never print porcelain output: filenames can contain private information.
worktree_status="$(git -C "$repo_root" status --porcelain --untracked-files=all 2>/dev/null)" \
    || fail "source worktree state is unavailable"
[[ -z "$worktree_status" ]] \
    || fail "source worktree must be clean before physical preparation"

bash "$repo_root/scripts/build-app.sh"
bash "$repo_root/scripts/verify-spike-signed-build.sh" \
    "$repo_root/dist/Wheel.app" \
    --summary-json "$summary_json"

echo "SPIKE-001 physical preparation PASS"
echo "Next: run swift run wheel-input-diagnostics and complete the documented matrix."
