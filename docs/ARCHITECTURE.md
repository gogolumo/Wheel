# Architecture

Wheel is intentionally designed as a **modular monolith**.

The domain owns stable product semantics. Native macOS code is treated as an integration boundary rather than being allowed to leak platform behavior into the history model.

## Modules

### WheelDomain

Framework-independent Swift values and invariants:

- `Direction`
- `TriggerType`
- `GestureSession`
- `ContextEntry`
- `ContextHistory`
- `RestorationResult`
- `RestorationDepth`

This target must not import SwiftUI, AppKit, Accessibility, SwiftData, or app-specific integrations.

### WheelCore

Application-level orchestration that coordinates domain objects while keeping platform dependencies outside the core.

The current slice includes `SpatialNavigationController`, whose first responsibility is enforcing one active `GestureSession`.

### Native macOS boundary — next milestone

The native layer will own:

- menu-bar lifecycle
- TCC permission preflight / recovery
- global input observation
- workspace/application activation observation
- Accessibility window probing
- generic restoration
- app-specific `ContextAdapter` implementations
- local persistence

## Canonical semantics

Wheel is not a launcher or radial menu.

- LEFT = previous global work context
- RIGHT = next global work context
- UP/DOWN are not part of the MVP

Application adapters may change **restoration depth**, but may not redefine the direction operators.

## History branching

For a trail:

```text
A → B → C
```

Navigating LEFT to `B` keeps the full history:

```text
A → [B] → C
```

so RIGHT still selects `C`.

Only **independent new work** replaces the forward suffix:

```text
A → [B] → C
          ↓ independently enter D

A → B → [D]
```

A context produced by Wheel restoration must never be treated as independent work and appended again.

## Restoration

Native adapters return an honest result:

- success
- partial
- failed
- cancelled
- unavailable
- permission denied

Only success and partial success may commit `ContextHistory.currentPosition`.

The restoration depth is separate:

- none
- application
- window
- semantic

This prevents a generic application activation from being presented as an exact deep restore.

## Privacy boundary

The pure domain layer stores a minimal `applicationBundleID` plus an opaque context token.

The native capture layer is responsible for ensuring that token is privacy-safe and does not contain document content, source code, page bodies, cookies, or other unnecessary data.


## Native presentation

The canonical production visual contract is [DESIGN.md](../DESIGN.md). `WheelApp`
owns semantic visual tokens, one role-aware `WheelGlassSurface`, rounded annular
sector geometry, the center hub, a read-only application detail panel, compact
menu controls, and native sidebar/Form Settings. `WheelApplicationPresentation`
maps run state and pin state to truthful labels and release hints without
performing restoration or changing destination eligibility.

The glass boundary conditionally compiles macOS 26 native glass with Swift 6.2+
and retains native Material on macOS 14+. Reduce Transparency and Increase
Contrast choose opaque semantic surfaces. The circular hub uses standard
material to avoid layering native glass inside native glass. No package, shader,
remote service, or screenshot capture is used.

The single nonactivating, click-through `WheelGestureOverlayPanelController`
keeps its window level, Space/full-screen behavior, generation guards, and
main-screen placement policy. Its bounded 820×520 pt composition includes a
492 pt ring and 276 pt context surface, with proportional fitting for small
visible frames. It still never reads pointer coordinates for panel placement.
No new input handlers or clickable actions are attached to that panel.

Explicit visual fixtures isolate default settings, pins, and history in memory
before stores are constructed. They never start permission checks, event taps,
application capture, or native pin resolution. The offscreen export path renders
only a synthetic view subtree. [QA](LIQUID_GLASS_QA.md) distinguishes deterministic
checks from pending physical macOS evidence. The inherited radial experiment
does not supersede the repository's LEFT/RIGHT or history contract.
