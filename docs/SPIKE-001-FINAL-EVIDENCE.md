# SPIKE-001 — Final feasibility evidence gate

Status: **PHYSICAL EVIDENCE REQUIRED — no GO/ADJUST/STOP decision yet**

This document closes the gap between automated feasibility evidence and the physical Mac evidence required to finish SPIKE-001 honestly.

## Question

Can Wheel use public macOS APIs to observe a global trigger plus pointer displacement, classify a gesture as LEFT / RIGHT / NONE with interactive latency, remain listen-only, recover safely, and avoid collecting unnecessary user data?

Canonical navigation semantics remain:

- LEFT = previous
- RIGHT = next

Radial selection experiments do not change that contract in SPIKE-001.

## Reused implementation evidence

SPIKE-001 does not create a second input stack. The final branch reuses the newer input feasibility infrastructure already present in the SPIKE-002 stack:

- `GlobalInputMonitor`
- `HorizontalGestureClassifier`
- `InputSpikeRunStatistics`
- `InputSpikeRunSummary`
- `InputSpikeEvidenceAssessment`
- `wheel-input-spike`
- `wheel-evidence-check`

The monitor is listen-only. Evidence is aggregate and must not persist typed text, raw key history, window contents, screenshots, filenames, document contents, URLs, browser history, absolute pointer coordinates, or hardware serial numbers.
The checker rejects unrecognized top-level JSON fields so an export cannot carry
unreviewed metadata alongside the approved aggregate schema.

## Automated acceptance

Before a final decision, GitHub Actions must pass the package build, tests, and `wheel-demo`. Classifier coverage must include:

- clear LEFT and RIGHT
- below-threshold NONE
- exact distance threshold
- exact dominance threshold
- very large displacement
- origin/noise samples
- small movement in either direction
- final displacement after reversal
- no movement
- duration-independent classification

Newer GestureSession/QA work may be cited for single-active-session and stale-callback invariants; do not duplicate those implementations solely for this spike.

## Required physical run

From a Mac with Input Monitoring permission, fetch the review branch and first
create the signed-build attestation. The preparation command requires a clean,
published checkout and writes its privacy-safe JSON outside the repository:

```bash
cd ~/Documents/Wheel
git fetch origin
git switch fix/SPIKE-001-signed-build-evidence
git pull --ff-only
git status --short

WHEEL_CODESIGN_IDENTITY="APPLE IDENTITY" \
  bash scripts/prepare-spike-001-physical.sh
```

The `git status --short` output must be empty. The preparation command must end
with `SPIKE-001 physical preparation PASS` and create
`../spike-001-signed-build.json`. Do not move that file into the checkout:
doing so would make the source tree dirty and invalidate the attestation.

Run four independent 100-sequence slots. Keep an external tally of deliberate
attempts because a completely missed trigger cannot report itself. If 100
physical attempts finish before 100 sequences are observed, press Control-C so
the partial JSON records the miss.

```bash
bash scripts/run-spike-001-slot.sh caps-lock-built-in
bash scripts/run-spike-001-slot.sh caps-lock-external
bash scripts/run-spike-001-slot.sh right-option-built-in
bash scripts/run-spike-001-slot.sh right-option-external
```

Each slot command first validates `../spike-001-signed-build.json` against the
current clean checkout. It fails closed before listening for input if the
signed-build evidence is missing, malformed, stale, or was produced from a
different revision.

The slot runner fixes the trigger, label, 100-sequence target, and default
external JSON destination for each approved slot. It rejects a dirty or
unpublished checkout, an existing destination, and output inside the source
tree. Built-in/external remains an operator-selected condition; the runner does
not query or retain a device name, serial number, vendor, or product identifier.

For every slot, exercise Finder, Chrome, VS Code, full-screen, sleep/wake, and
timeout recovery; review event order, intended versus observed direction,
stuck state, and native side effects. Record at least 120 seconds of the run.
Only after reviewing those observations may the operator replace `go` below
with the actual decision. The canonical gate passes only for a reviewed `go`;
`adjust` and `stop` remain valid recorded decisions but deliberately fail the
GO gate.

```bash
run_labels=(caps-lock-built-in caps-lock-external right-option-built-in right-option-external)
scenarios=(finder chrome vscode full-screen sleep-wake timeout-recovery)
reviews=(event-order intended-vs-observed stuck-state side-effects)
scenario_args=()
review_args=()
for run_label in "${run_labels[@]}"; do
  for scenario in "${scenarios[@]}"; do
    scenario_args+=(--attest-run-scenario "$run_label" "$scenario")
  done
  for review in "${reviews[@]}"; do
    review_args+=(--attest-run-review "$run_label" "$review")
  done
done

swift run wheel-evidence-check \
  --profile spike-001-final \
  --attempt-count caps-lock-built-in 100 \
  --attempt-count caps-lock-external 100 \
  --attempt-count right-option-built-in 100 \
  --attempt-count right-option-external 100 \
  "${scenario_args[@]}" \
  "${review_args[@]}" \
  --attest-environment clean-account \
  --signed-build-evidence ../spike-001-signed-build.json \
  --recording-duration-seconds 120 \
  --record-decision go \
  ../caps-lock-built-in.json \
  ../caps-lock-external.json \
  ../right-option-built-in.json \
  ../right-option-external.json
```

The profile supplies the fixed trigger, named-slot, target, reliability,
direction-coverage, latency, scenario, review, recording, and decision
requirements. It intentionally does not supply `--attempt-count`; each physical
slot needs an explicit operator attestation. A valid interrupted export that was
configured for 100 sequences and contains 99 observed sequences can satisfy the
aggregate 99/100 criterion, but the operator must still report that 100
deliberate attempts were made. The checker cannot independently prove a missed
trigger, physical device identity, scenario execution, stuck state, or native
side effects.

The three direction requirements prevent a run containing only one classifier
result from passing as the physical LEFT / RIGHT / NONE exercise. They prove
only aggregate coverage; the operator still records intended versus observed
directions and any wrong result in the manual matrix.

During each slot's 100 deliberate sequences, alternate LEFT and RIGHT movements
and include several intentional below-threshold releases to exercise NONE.
Record any focus theft, clicks, pointer warping, typed characters, unintended
navigation, stuck trigger state, missed deliberate attempt, and Caps Lock state
change.

The JSON's `observed sequences` is not by itself proof that 99 of 100 deliberate physical attempts were observed: the operator must also report the number of deliberate attempts and any misses/side effects.

## Sleep/wake and recovery gate

Before final GO, physical evidence must also show that after sleep/wake the monitor can accept a fresh gesture without a stuck held/tracking state. Any event-tap recovery observed during the run must leave the next gesture usable. If recovery cannot be induced safely, automated recovery coverage plus a normal physical sleep/wake pass may be recorded separately; do not claim an induced physical recovery that did not happen.

## Decision rule

Record exactly one final decision only after the physical evidence exists:

- **GO**: required physical reliability and latency pass, no destructive/native side effects, lifecycle/recovery evidence is acceptable, privacy constraints hold.
- **ADJUST**: the public-API approach is viable but one or more thresholds, trigger choices, lifecycle details, or conflict policies require a bounded change.
- **STOP**: no tested public-API path can satisfy the feasibility criteria without unacceptable conflicts or reliability/privacy failure.

CI success alone is never a GO decision.

## Current blocker

The remaining blocker is physical Mac evidence. Until that evidence is attached and assessed, SPIKE-001 must remain in Review & Test/Blocked rather than Done.
