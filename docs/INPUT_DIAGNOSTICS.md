# Wheel Input Diagnostics

`wheel-input-diagnostics` is a temporary native macOS companion for the
SPIKE-002 physical trigger matrix. It makes the listen-only input harness
observable without requiring terminal logs. It is not the production Wheel
history UI and it never performs navigation.

## Run it

Use macOS 14 or newer with the full Xcode toolchain selected:

```bash
swift build --product wheel-input-diagnostics
swift run wheel-input-diagnostics
```

The app places a status icon in the menu bar. Open it to see permission state,
the selected trigger, held/released state, aggregate results, callback latency,
and event-tap recoveries. Use **Open Window** if a standalone diagnostics window
is more convenient during the matrix.

When launched from Terminal, macOS may attribute Input Monitoring access to the
terminal host. When launched from Xcode, grant access to Xcode. Use the explicit
**Request Access** button once, then **Open Privacy Settings** if macOS still
reports the permission as missing. The app does not repeat the system request
automatically.

## Collect a run

1. Choose a privacy-safe run label and the candidate trigger. Labels are limited
   to 64 letters, numbers, spaces, hyphens, and underscores; paths, URLs, line
   breaks, and leading or trailing whitespace are rejected.
2. Leave the target at 30 for the SPIKE-002 candidate matrix.
3. Press **Start Listening**.
4. Hold the trigger, move, and release. Confirm that the status visibly changes
   to **Trigger Held**, **Matching trigger signals** advances, **Last trigger
   edge** reaches DOWN then UP, and the result becomes LEFT, RIGHT, or NONE
   exactly once. Non-configured mouse buttons do not advance this counter.
5. At the target, the app stops automatically and marks the run **Completed**.
6. Use **Export JSON**. If the physical-attempt tally ends before Wheel reaches
   its target, use **Stop & Save Partial Evidence** instead.

The export uses the same current `InputSpikeRunSummary` schema (version 3) as
`wheel-input-spike`. It stores configuration, aggregate counters, latency,
recovery count, and completion reason. It does not store pointer coordinates,
window titles, URLs, paths, typed content, raw key history, account names, or
device identifiers.

The matching-signal count and last DOWN/UP edge are transient troubleshooting
feedback. They reset with the run and are intentionally absent from exported
JSON, along with key codes and button numbers from individual events.

The menu-bar symbol and text distinguish Permission Required, Ready, Listening,
Trigger Held, Completed, Stopped, Event Tap Recovered, and Error. Color is never
the only state indicator.

## Recovery and sleep/wake

An event-tap recovery clears transient trigger state and increments the recovery
counter. After system wake, the UI stops the active run and preserves it as
partial evidence instead of claiming that a trigger is still held. Start a new
run after checking the permission and physical trigger state.

## Evidence limits

The UI cannot count a completely missed physical attempt or observe native side
effects such as Caps Lock state, Option-modified app behavior, browser Back, or
mouse-driver overlays. Keep the external intended-attempt tally and manual
side-effect notes required by `TRIGGER_CONFLICT_SPIKE.md`. A green build and a
completed JSON file do not close the physical evidence gate by themselves.
