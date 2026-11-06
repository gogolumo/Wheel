#!/usr/bin/env bash
set -euo pipefail

# Run exactly one canonical SPIKE-001 physical slot. The slot name is the only
# device descriptor retained in evidence; no hardware identifier is queried.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

fail() {
    echo "SPIKE-001 physical slot FAILED: $1" >&2
    exit 1
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
    fail "expected a canonical slot and optional summary destination"
fi

slot="$1"
case "$slot" in
    caps-lock-built-in|caps-lock-external)
        trigger="caps-lock"
        ;;
    right-option-built-in|right-option-external)
        trigger="right-option"
        ;;
    *)
        fail "unsupported physical slot"
        ;;
esac

summary_json="${2:-$repo_root/../$slot.json}"
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

head_revision="$(git -C "$repo_root" rev-parse --verify HEAD 2>/dev/null)" \
    || fail "current source revision is unavailable"
upstream_revision="$(git -C "$repo_root" rev-parse --verify '@{upstream}' 2>/dev/null)" \
    || fail "a published upstream source revision is required"
[[ "$head_revision" == "$upstream_revision" ]] \
    || fail "current source revision must equal the published branch head"

# Do not print porcelain output: filenames can contain private information.
worktree_status="$(git -C "$repo_root" status --porcelain --untracked-files=all 2>/dev/null)" \
    || fail "source worktree state is unavailable"
[[ -z "$worktree_status" ]] \
    || fail "source worktree must be clean before a physical slot"

cd "$repo_root"
swift run wheel-input-spike \
    --trigger "$trigger" \
    --sequences 100 \
    --label "$slot" \
    --summary-json "$summary_json"
