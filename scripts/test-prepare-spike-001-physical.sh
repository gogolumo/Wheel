#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
script="$repo_root/scripts/prepare-spike-001-physical.sh"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fail() {
    echo "SPIKE-001 physical preparation tests FAILED: $1" >&2
    exit 1
}

required_handoff=(
    'echo "SPIKE-001 physical preparation PASS"'
    'bash scripts/run-spike-001-slot.sh caps-lock-built-in'
    'bash scripts/run-spike-001-slot.sh caps-lock-external'
    'bash scripts/run-spike-001-slot.sh right-option-built-in'
    'bash scripts/run-spike-001-slot.sh right-option-external'
)
for text in "${required_handoff[@]}"; do
    grep -Fq -- "$text" "$script" \
        || fail "successful preparation handoff is incomplete"
done
if grep -Fq -- "swift run wheel-input-diagnostics" "$script"; then
    fail "stale diagnostics handoff returned"
fi

# Exercise the successful path in an isolated published checkout. Stub only the
# expensive app build and codesign verifier; keep the preparation script and
# its Git cleanliness/upstream checks real.
success_repo="$test_root/repo"
success_remote="$test_root/remote.git"
success_log="$test_root/preparation-invocation"
success_summary="$test_root/spike-001-signed-build.json"
mkdir -p "$success_repo/scripts"
cp "$script" "$success_repo/scripts/prepare-spike-001-physical.sh"

cat >"$success_repo/scripts/build-app.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "build" >>"$WHEEL_PREP_TEST_LOG"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
mkdir -p "$repo_root/dist/Wheel.app"
EOF

cat >"$success_repo/scripts/verify-spike-signed-build.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ $# -eq 3 && "$2" == "--summary-json" ]]
printf '%s\n' "verify" >>"$WHEEL_PREP_TEST_LOG"
printf '%s\n' '{}' >"$3"
EOF
chmod +x "$success_repo/scripts/"*.sh

git init -q --bare "$success_remote"
git -C "$success_repo" init -q
git -C "$success_repo" config user.name "Wheel Test"
git -C "$success_repo" config user.email "wheel-test@example.invalid"
git -C "$success_repo" add scripts
git -C "$success_repo" commit -qm "test fixture"
git -C "$success_repo" remote add origin "$success_remote"
git -C "$success_repo" push -qu origin HEAD:main
git -C "$success_repo" branch --set-upstream-to=origin/main >/dev/null

expected_success_output='SPIKE-001 physical preparation PASS
Next: run the four canonical physical slots:
  bash scripts/run-spike-001-slot.sh caps-lock-built-in
  bash scripts/run-spike-001-slot.sh caps-lock-external
  bash scripts/run-spike-001-slot.sh right-option-built-in
  bash scripts/run-spike-001-slot.sh right-option-external'
success_output="$(
    cd /
    WHEEL_CODESIGN_IDENTITY="private identity" \
        WHEEL_PREP_TEST_LOG="$success_log" \
        bash "$success_repo/scripts/prepare-spike-001-physical.sh"
)" || fail "valid published preparation failed"
[[ "$success_output" == "$expected_success_output" ]] \
    || fail "successful preparation emitted an unexpected handoff"
[[ -f "$success_summary" && "$(<"$success_log")" == $'build\nverify' ]] \
    || fail "successful preparation skipped or reordered a required step"
[[ "$success_output" != *"$test_root"* && "$success_output" != *"private identity"* ]] \
    || fail "successful preparation exposed private data"

assert_failure() {
    local expected="$1"
    shift
    local output
    if output="$({ "$@"; } 2>&1)"; then
        fail "invalid preparation unexpectedly passed"
    fi
    [[ "$output" == "SPIKE-001 physical preparation FAILED: $expected" ]] \
        || fail "preparation emitted an unexpected diagnostic"
    [[ "$output" != *"$repo_root"* && "$output" != *"$test_root"* ]] \
        || fail "preparation diagnostic exposed a local path"
}

assert_failure \
    "summary destination must be outside the source checkout" \
    env WHEEL_CODESIGN_IDENTITY="private identity" \
    bash "$script" "$repo_root/private-evidence.json"

assert_failure \
    "WHEEL_CODESIGN_IDENTITY is required" \
    env -u WHEEL_CODESIGN_IDENTITY \
    bash "$script" "$test_root/evidence.json"

touch "$test_root/existing.json"
assert_failure \
    "summary destination must not already exist" \
    env WHEEL_CODESIGN_IDENTITY="private identity" \
    bash "$script" "$test_root/existing.json"

assert_failure \
    "expected an optional summary destination" \
    bash "$script" one two

echo "SPIKE-001 physical preparation tests PASS"
