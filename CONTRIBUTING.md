# Contributing

Wheel is currently a solo-developer MVP, but the repository is structured so changes stay reviewable.

## Before changing semantics

The following are product invariants, not implementation details:

- LEFT = previous global work context
- RIGHT = next global work context
- Back/Forward navigation never deletes the forward suffix
- only independent new work replaces a forward suffix
- Wheel-restored contexts must not be recorded again as independent work
- failed/cancelled/unavailable/permission-denied restores do not move history
- only one gesture session may be active
- no accounts, cloud sync, arbitrary macros, or UP/DOWN semantics in the MVP

A change to these rules should be treated as a product/architecture decision, not a refactor.

## Local checks

```bash
swift test
swift run wheel-demo
```

Keep the domain target free of AppKit/SwiftUI/platform dependencies.
