# Wheel

**A macOS spatial navigation layer for moving through global work contexts.**

Wheel explores a simple idea: **LEFT means go to the previous work context, RIGHT means go to the next one** — across applications and windows, not just inside a browser or editor.

Instead of acting as another launcher, radial menu, or macro system, Wheel keeps a local history of stable work contexts and restores the deepest safe context supported by each application.

> **Status:** early MVP / engineering prototype. The current repository contains the first testable domain slice: history semantics, branching rules, restoration outcomes, and deterministic tests. Native input capture and the menu-bar shell are the next milestones.

## Why Wheel?

Laptop workflows are fragmented across apps, windows, tabs, folders, and files. Moving between them usually means visually searching, reaching for keyboard shortcuts, or repeatedly navigating window switchers.

Wheel is designed around a small system-wide spatial grammar:

- **LEFT** → previous global work context
- **RIGHT** → next global work context
- no launcher grid
- no radial menu
- no arbitrary macro layer
- local-first, privacy-minimal history

The goal is to make context switching feel closer to browser Back/Forward — but for the desktop as a whole.

## Current vertical slice

The first implementation focuses on the hardest part to get right before touching platform APIs: **history semantics**.

Implemented:

- immutable `ContextEntry` values
- ordered `ContextHistory`
- Back/Forward target selection
- forward-branch preservation after navigation
- forward-branch replacement only after independent new work
- duplicate suppression for the current context
- explicit restoration outcomes
- commit rules where failed/cancelled/unavailable/permission-denied restores do **not** move history
- unit tests for the core invariants
- a small CLI demo that replays the canonical `A → B → C` scenario

Planned next:

1. native macOS menu-bar shell
2. permission/readiness model
3. global input feasibility spikes
4. stable app/window context capture
5. generic restoration
6. app adapter architecture
7. HUD, privacy controls, reliability, signing and release

## Try the domain demo

Requirements:

- macOS 14+
- Swift 5.10+ / Xcode 16+

```bash
swift test
swift run wheel-demo
```

The demo shows:

```text
A → B → C
LEFT  => B
RIGHT => C
LEFT  => B
independent D => A → B → D
```

The important behavior is that a normal Back operation does **not** destroy the forward branch. The forward branch is replaced only when the user independently enters a new stable context after going back.

## Architecture

Wheel is designed as a modular monolith:

```text
WheelDomain
  ├─ ContextEntry
  ├─ ContextHistory
  ├─ Direction
  ├─ RestorationDepth
  └─ RestorationResult

WheelCore
  └─ navigation / restoration policy

Native macOS boundary (next)
  ├─ input capture
  ├─ workspace + Accessibility observation
  ├─ permissions
  └─ application adapters
```

Application-specific behavior is intended to stay behind a `ContextAdapter` boundary so Chrome, Finder, VS Code, and other integrations cannot redefine Wheel's LEFT/RIGHT semantics.

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Product principles

- **Stable semantics:** LEFT/RIGHT always mean global previous/next work context.
- **Honest restoration:** Wheel reports the depth it actually restored instead of pretending every context is exact.
- **No history corruption:** failure, cancellation, missing permissions, unavailable targets, and empty history do not move the current position.
- **Local-first:** no account, cloud sync, or AI is required for the MVP.
- **Privacy-minimal:** context history should store only what is necessary for restoration.
- **One active gesture session:** ambiguous concurrent navigation attempts are rejected rather than guessed.

## Roadmap

The implementation plan is organized around measurable milestones rather than feature accumulation:

- M0 — repository and development environment
- M1 — feasibility spikes
- M2 — menu-bar shell and permission onboarding
- M3 — gesture input
- M4 — stable context capture
- M5 — ContextHistory
- M6 — generic restoration
- M7 — adapter architecture
- M8 — selected deep adapters
- M9 — HUD and settings
- M10 — privacy and persistence
- M11 — reliability and performance
- M12 — packaging and beta
- M13 — public MVP release

See [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Privacy

Wheel is intentionally designed without accounts, cloud history, or content indexing for the MVP. The native implementation will use the minimum metadata required to identify and restore a useful work context.

See [`docs/PRIVACY.md`](docs/PRIVACY.md).

## License

MIT — see [`LICENSE`](LICENSE).
