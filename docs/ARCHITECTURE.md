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
