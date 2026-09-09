# Roadmap

This repository follows a gate-driven macOS-first roadmap.

## M0 — Repository and development environment

- reproducible Swift workspace
- module skeleton
- tests and CI
- contribution/project rules
- no secrets in git

**Current status:** in progress. The first domain slice and CI-ready Swift package are present.

## M1 — Feasibility spikes

Validate the platform assumptions before building product UI:

- global trigger + pointer observation
- candidate triggers and conflicts
- TCC permissions
- stable app/window identity
- generic activation/restoration
- optional deep app integrations
- pointer strategy
- signing/notarization flow

Each spike ends in **GO / ADJUST / STOP** rather than silently hard-coding an assumption.

**Current work:** [global Caps Lock and pointer input spike](https://github.com/gogolumo/Wheel/issues/1).

## M2 — Menu-bar shell and permission onboarding

A quiet macOS menu-bar app that:

- shows readiness
- explains required permissions
- recovers from denial/revocation
- never mutates navigation state while blocked

## M3 — Gesture input

Translate approved raw input into one safe:

- LEFT
- RIGHT
- NONE

Only one `GestureSession` may exist at a time.

## M4 — Stable context capture

Record stable work contexts while ignoring transient controls.

Initial target:

- application identity
- generic window identity where reliable
- stability/debounce
- deduplication
- restoration-source suppression
- privacy-minimal schema

## M5 — ContextHistory

Pure, deterministic Back/Forward and branching semantics.

**The initial implementation of this milestone is already represented by the current Swift package and tests.**

## M6 — Generic restoration

Restore application/window context and commit history only for truthful success / partial outcomes.

## M7 — Adapter architecture

Introduce a `ContextAdapter` protocol and deterministic registry with generic fallback.

## M8 — Selected deep adapters

Ship only integrations that pass feasibility gates. Finder is the most likely early candidate; browser/editor deep restoration stays deferred unless a supported path is demonstrated.

## M9 — HUD and settings

Small delayed feedback, calibration/practice, support matrix, accessibility.

Wheel must not expand into a persistent radial menu.

## M10 — Privacy and persistence

- local-only history
- exclusions
- retention
- clear-history transaction
- minimal stored fields

## M11 — Reliability and performance

- sleep/wake recovery
- rapid input serialization
- timeout isolation
- latency and idle-overhead profiling
- redacted diagnostics
- soak testing

## M12 — Packaging and beta

- Developer ID
- notarization
- DMG
- clean-machine smoke tests
- tester feedback

## M13 — Public MVP

- signed source tag
- notarized artifact
- checksums
- known limitations
- support path
- GitHub release
