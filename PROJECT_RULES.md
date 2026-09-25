# Wheel project rules

Status: active for the macOS MVP.

This file records the project-level rules that must stay true across implementation, review, testing, and release work. A semantic change to these rules requires an explicit change request and a superseding ADR; it must not be introduced as an incidental refactor.

## Product semantics

1. LEFT always means the previous global work context.
2. RIGHT always means the next global work context.
3. Back/Forward navigation does not delete the existing forward suffix.
4. Only independently entered new work replaces the forward suffix.
5. Contexts restored by Wheel are not re-recorded as independent work.
6. Failed, cancelled, unavailable, and permission-denied restoration does not advance history.
7. Only one GestureSession may be active at a time.
8. UP/DOWN navigation, accounts, cloud sync, and arbitrary macros are outside the MVP.

Canonical public operation intent remains:

- `startGesture(triggerType: TriggerType)`
- `completeGesture(direction: Direction)`

Concrete implementation may route through reducers/coordinators, but must preserve these semantics.

## Review rule

Any pull request that changes navigation, history, restoration, gesture lifecycle, privacy-sensitive capture, or native input behavior must:

- link the relevant Trello/GitHub work;
- state which invariants are affected;
- include automated checks where the behavior is testable;
- include physical macOS evidence when behavior depends on input, permissions, windows, focus, sleep/wake, or other system APIs;
- document rollback/fallback behavior.

The repository PR template is the review surface for this rule.

## Solo workflow and WIP

Wheel is a solo-maintained MVP. Work should stay small and verifiable.

Board policy:

- In Progress target WIP: 1 engineering card;
- Review & Test target WIP: 2 cards;
- do not pull new work while an unresolved P0 blocker prevents valid progress;
- take Ready work top-to-bottom unless a dependency, blocker, or new evidence changes the order.

The WIP values are operational targets, not permission to falsify board state. If active work temporarily exceeds a limit, record why and reduce WIP before expanding scope again.

## AI-assisted changes

AI may assist implementation, documentation, testing, or review, but it is not evidence by itself.

For AI-assisted work:

- use one card-sized scope at a time;
- provide acceptance criteria and invariants before code changes;
- verify macOS/platform API claims against source code, SDK behavior, official docs, or physical evidence as appropriate;
- review the diff and be able to explain every accepted change;
- run required automated checks;
- do not treat CI as proof of physical macOS behavior;
- do not treat generated code as proof that a feasibility assumption passed;
- do not expose private Wheel history, titles, paths, URLs, typed text, document contents, screenshots, or raw logs to an external AI service;
- do not autonomously merge/release a risky system integration without its required evidence.

## Privacy baseline

Wheel is local-first. The MVP must not persist document/page bodies, source code, typed text, clipboard contents, screenshots, raw input history, or cloud history. Diagnostics must stay privacy-safe and must not become a second context-history store.

See also `docs/PRIVACY.md`, `docs/ARCHITECTURE.md`, and `CONTRIBUTING.md`.
