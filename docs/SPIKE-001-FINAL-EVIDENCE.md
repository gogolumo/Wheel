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

From a Mac with Input Monitoring permission, run:

```bash
cd ~/Documents/Wheel/Wheel
git fetch origin
git switch spike/SPIKE-001-final-evidence
git pull --ff-only

swift run wheel-input-spike \
  --trigger right-option \
  --sequences 100 \
  --label "SPIKE-001-final" \
  --summary-json /tmp/wheel-spike-001-final.json

swift run wheel-evidence-check \
  /tmp/wheel-spike-001-final.json \
  --expected-trigger right-option \
  --minimum-observed 99 \
  --maximum-median-latency-ms 25
```

During the 100 deliberate sequences, alternate LEFT and RIGHT movements and include several intentional below-threshold releases to exercise NONE. Run across Finder, Chrome, VS Code, a normal Space, and a full-screen Space. Record any focus theft, clicks, pointer warping, typed characters, unintended navigation, stuck trigger state, or missed deliberate attempt.

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
