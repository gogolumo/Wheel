# Architecture Decision Register

This register records the current macOS MVP architecture decisions. A decision may be accepted while a linked feasibility gate remains open; acceptance of the decision does not mean the gate has passed.

## ADR-001 — macOS-first release

**Status:** Accepted

Wheel ships macOS-first with a minimum deployment target of macOS 14. The current Swift package declares macOS 14 and the active native work is macOS-specific.

**Rationale:** global input, TCC permissions, focus/window restoration, AppKit/ApplicationServices integration, signing, and notarization are the highest-risk parts of the MVP.

**Revisit:** after M13 and at least four weeks of beta evidence.

## ADR-002 — SwiftUI with focused AppKit/native bridges

**Status:** Accepted

Use SwiftUI for ordinary product UI and AppKit/Core Graphics/ApplicationServices at native boundaries. Views must not own event taps or history semantics. Native bridges remain isolated and testable.

**Evidence:** the active `wheel-app` stack uses SwiftUI plus AppKit `NSPanel`/application lifecycle code and a separate `WheelMacOS` boundary.

**Revisit:** if a measured prototype proves a required UI behavior cannot be implemented safely with this split.

## ADR-003 — Gate input capture behind event-tap feasibility

**Status:** Accepted with gate

Use a native CGEventTap-backed input boundary for gesture candidates, but ship only trigger modes that pass physical-device, application, full-screen, sleep/wake, TCC, and side-effect testing.

**Current gate state:** SPIKE-001/SPIKE-002 remain open for final physical evidence. Caps Lock has a demonstrated alphaShift side effect; Right Option has encouraging smoke evidence but the full final matrix is not yet complete.

**Revisit:** on supported macOS behavior changes or failed final feasibility evidence.

## ADR-004 — Repository-backed SwiftData persistence

**Status:** Proposed / pending POC

The intended release direction is an in-memory repository during POC and a SwiftData-backed local store behind narrow store protocols.

This decision is not yet accepted because the required persistence POC, PRIV-001, QA-018, schema/migration evidence, and relaunch verification are not present in the current implementation.

## ADR-005 — Isolate restoration through ContextAdapter

**Status:** Accepted as architecture direction; implementation pending

App-specific restoration must stay behind a ContextAdapter-style boundary. Adapters may improve restoration depth but may not mutate ContextHistory directly or redefine LEFT/RIGHT semantics. A coordinator owns result validation and history-position commits.

The production adapter protocol/registry is still pending M7 work, so this ADR does not claim adapter implementation is complete.

**Revisit:** if a third production adapter cannot fit the boundary without leaking app-specific semantics into history.

## ADR-006 — Developer ID + notarized direct distribution

**Status:** Accepted as release direction; release evidence pending

Public distribution target is a non-sandboxed hardened-runtime Developer ID-signed and notarized build distributed directly, with the Mac App Store deferred.

Local ad-hoc app packaging exists, but Developer ID signing, notarization, DMG, clean-machine installation, and release automation remain SPIKE-010 / release work.

## ADR-007 — Privacy-redacted OSLog diagnostics

**Status:** Proposed / implementation pending

The intended diagnostic model is unified OSLog categories with private values redacted and user-initiated export. No remote telemetry is planned for MVP.

This ADR is not yet accepted as implemented because the repository does not currently contain the required OSLog diagnostics/export and forbidden-field scan evidence.

## ADR-008 — Minimal local metadata only

**Status:** Accepted as privacy contract; persistence enforcement pending

Wheel stores identity/restoration metadata, not content. Screenshots, document/page bodies, source code, typed text, clipboard content, raw input history, and cloud history are outside the persistence contract.

The repository already documents the minimal/local privacy boundary. Persistence-specific enforcement, exclusions-before-write, bounded retention, and atomic clear remain later PRIV/QA work.

**Revisit:** any new stored field or external data transfer requires an ADR and privacy/threat review.
