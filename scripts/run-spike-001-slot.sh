#!/usr/bin/env bash
set -euo pipefail

# Run exactly one canonical SPIKE-001 physical slot. The slot name is the only
# device descriptor retained in evidence; no hardware identifier is queried.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
source "$repo_root/scripts/lib/app-process.sh"
slot_lock="$repo_root/dist/.spike-001-slot.lock"
slot_lock_pid="$slot_lock/pid"
slot_lock_acquired=0

cleanup() {
    local status=$?
    local release_failed=0
    trap - EXIT
    if [[ "$slot_lock_acquired" -eq 1 ]]; then
        if [[ -f "$slot_lock_pid" && ! -L "$slot_lock_pid" \
            && "$(<"$slot_lock_pid")" == "$$" ]]; then
            rm -f -- "$slot_lock_pid" 2>/dev/null || release_failed=1
        else
            release_failed=1
        fi
        if ! rmdir "$slot_lock" 2>/dev/null; then
            release_failed=1
        fi
        if [[ "$release_failed" -ne 0 ]]; then
            echo "SPIKE-001 physical slot FAILED: process lock could not be released" >&2
            status=1
        fi
    fi
    exit "$status"
}
trap cleanup EXIT

fail() {
    echo "SPIKE-001 physical slot FAILED: $1" >&2
    exit 1
}

discard_summary() {
    if [[ -f "$summary_json" || -L "$summary_json" ]]; then
        rm -f -- "$summary_json" 2>/dev/null \
            || fail "could not discard rejected capture output"
    fi
}

acquire_slot_lock() {
    if ! mkdir "$slot_lock" 2>/dev/null; then
        local owner_pid
        [[ -d "$slot_lock" && ! -L "$slot_lock" \
            && -f "$slot_lock_pid" && ! -L "$slot_lock_pid" ]] \
            || fail "another physical slot is already running"
        owner_pid="$(<"$slot_lock_pid")"
        [[ "$owner_pid" =~ ^[1-9][0-9]*$ ]] \
            || fail "another physical slot is already running"
        if kill -0 "$owner_pid" 2>/dev/null; then
            fail "another physical slot is already running"
        fi
        rm -f -- "$slot_lock_pid" 2>/dev/null \
            && rmdir "$slot_lock" 2>/dev/null \
            && mkdir "$slot_lock" 2>/dev/null \
            || fail "stale physical slot lock could not be recovered"
    fi
    printf '%s\n' "$$" >"$slot_lock_pid" 2>/dev/null \
        || fail "physical slot lock owner could not be recorded"
    slot_lock_acquired=1
}

if [[ $# -lt 1 || $# -gt 3 ]]; then
    fail "expected a canonical slot, optional summary destination, and optional signed-build evidence"
fi

slot="$1"
case "$slot" in
    caps-lock-built-in|caps-lock-external)
        trigger="caps-lock"
        evidence_trigger="capsLock"
        ;;
    right-option-built-in|right-option-external)
        trigger="right-option"
        evidence_trigger="rightOption"
        ;;
    *)
        fail "unsupported physical slot"
        ;;
esac

summary_json="${2:-$repo_root/../$slot.json}"
signed_build_evidence="${3:-$repo_root/../spike-001-signed-build.json}"
capture_executable="$repo_root/dist/Wheel.app/Contents/MacOS/WheelInputSpike"
app_executable="$repo_root/dist/Wheel.app/Contents/MacOS/Wheel"
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

signed_build_dir="$(dirname "$signed_build_evidence")"
signed_build_name="$(basename "$signed_build_evidence")"
[[ -n "$signed_build_name" && "$signed_build_name" != "." && "$signed_build_name" != ".." ]] \
    || fail "signed-build evidence path is invalid"
[[ -d "$signed_build_dir" ]] || fail "signed-build evidence directory is unavailable"
signed_build_dir="$(cd "$signed_build_dir" && pwd -P)" \
    || fail "signed-build evidence directory is unavailable"
signed_build_evidence="$signed_build_dir/$signed_build_name"
case "$signed_build_evidence" in
    "$repo_root"|"$repo_root"/*)
        fail "signed-build evidence must be outside the source checkout"
        ;;
esac
[[ -f "$signed_build_evidence" && ! -L "$signed_build_evidence" ]] \
    || fail "signed-build evidence is unavailable"
[[ -f "$capture_executable" && -x "$capture_executable" && ! -L "$capture_executable" ]] \
    || fail "signed capture harness is unavailable"
for command in pgrep ps; do
    command -v "$command" >/dev/null 2>&1 \
        || fail "process isolation check is unavailable"
done
acquire_slot_lock

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
[[ -z "$(wheel_find_running_pid "$app_executable" || true)" ]] \
    || fail "quit Wheel.app before a physical slot"

cd "$repo_root"
# The JSON attestation is not enough on its own: the app or nested executable
# could be replaced after preparation. Revalidate the actual signed artifact
# immediately before and after the physical capture.
bash "$repo_root/scripts/verify-spike-signed-build.sh" \
    "$repo_root/dist/Wheel.app" "$head_revision" >/dev/null 2>&1 \
    || fail "signed capture artifact verification failed"
swift run wheel-evidence-check --signed-build-only "$signed_build_evidence"
capture_exit=0
"$capture_executable" \
    --trigger "$trigger" \
    --sequences 100 \
    --label "$slot" \
    --source-revision "$head_revision" \
    --summary-json "$summary_json" \
    || capture_exit=$?

# Control-C is the documented way to preserve a 99/100 partial run. Validate
# that evidence before returning the original interrupt status. Other capture
# failures are not evidence and propagate immediately.
if [[ "$capture_exit" -ne 0 && "$capture_exit" -ne 130 ]]; then
    discard_summary
    exit "$capture_exit"
fi
if [[ ! -s "$summary_json" || -L "$summary_json" ]]; then
    discard_summary
    fail "input spike did not create evidence"
fi
# The production app owns a second global monitor. If it starts during the
# physical slot, the run is no longer an isolated measurement and cannot be
# accepted as reliability evidence.
if [[ -n "$(wheel_find_running_pid "$app_executable" || true)" ]]; then
    discard_summary
    fail "Wheel.app started during the physical slot"
fi
# Revalidate the signed source after the long-running physical capture. This
# closes the gap where the checkout or published branch could change after the
# preflight but before the JSON is accepted as evidence.
if ! bash "$repo_root/scripts/verify-spike-signed-build.sh" \
    "$repo_root/dist/Wheel.app" "$head_revision" >/dev/null 2>&1; then
    discard_summary
    fail "signed capture artifact verification failed"
fi
if ! swift run wheel-evidence-check --signed-build-only \
    "$signed_build_evidence"; then
    discard_summary
    fail "signed-build evidence postflight failed"
fi
if ! swift run wheel-evidence-check \
    --require-run "$slot" "$evidence_trigger" \
    --expected-trigger "$trigger" \
    --expected-sequence-target 100 \
    --expected-source-revision "$head_revision" \
    "$summary_json"; then
    discard_summary
    fail "capture evidence postflight failed"
fi
if [[ -n "$(wheel_find_running_pid "$app_executable" || true)" ]]; then
    discard_summary
    fail "Wheel.app started before evidence acceptance"
fi
exit "$capture_exit"
