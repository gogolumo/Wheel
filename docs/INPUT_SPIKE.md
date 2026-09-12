# M1 Global Input Spike

This executable tests Wheel's riskiest early assumption: whether a public,
listen-only macOS input path can reliably observe a held trigger and pointer
movement without intercepting normal input.

It is a diagnostic, not production gesture handling. A successful compile does
not prove that Caps Lock is viable; that decision requires repeated testing on a
real Mac.

## Fix the active Xcode toolchain

If `swift test` reports `no such module 'XCTest'`, Command Line Tools are active
instead of the full Xcode developer directory. Run:

```bash
xcode-select -p
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -version
swift --version
swift test
```

The first command should ultimately print:

```text
/Applications/Xcode.app/Contents/Developer
```

If Xcode has a different name or location, use its actual path.

## Run from Xcode

From the repository root:

```bash
open Package.swift
```

Then:

1. Select the `wheel-input-spike` scheme and `My Mac` destination.
2. Press Run.
3. When macOS asks, allow Xcode under **System Settings > Privacy & Security > Input Monitoring**.
4. Restart Xcode after changing the permission, then Run again.

To test Right Option as a comparison, open **Product > Scheme > Edit Scheme >
Run > Arguments** and add:

```text
--trigger right-option
```

## Run from Terminal

```bash
swift run wheel-input-spike
swift run wheel-input-spike --trigger right-option
```

When launched this way, grant Input Monitoring access to the terminal app rather
than Xcode.

Optional classifier tuning:

```bash
swift run wheel-input-spike --distance 100 --dominance 1.8
```

Give every evidence run a privacy-safe label and an observed-sequence target:

```bash
swift run wheel-input-spike \
  --trigger caps-lock \
  --sequences 100 \
  --label "built-in-trackpad-finder-windowed" \
  --summary-json "spike-001-built-in-trackpad.json"
```

The label must describe the test setup, not contain a serial number, account
name, document title, URL, or other personal data. The process prints live
sequence counts and median event-callback latency, then emits an aggregate
summary after the requested number of observed sequences. Pointer movement is
counted but not printed by default: synchronous console output for every move
can create event-tap backpressure and invalidate the latency measurement.

The optional JSON file contains only aggregate counters and threshold checks.
It never records coordinates, titles, paths, typed content, or hardware
identifiers. It still requires manual review because the harness cannot know
the physical-attempt count, stuck-state result, or native side effects.

For diagnosing event order only, enable detailed movement logs:

```bash
swift run wheel-input-spike --verbose-events --sequences 10 --label "ordering-check"
```

Do not use a verbose run as latency evidence. Use the default aggregate mode for
the 100-sequence acceptance run.

The monitor is created with `CGEventTapOptions.listenOnly`. It does not suppress,
rewrite, or post input events. Caps Lock may still toggle normally during this
experiment.

## Test protocol

First run a controlled set of 100 deliberate sequences. Keep an external tally
of physical attempts: a completely missed trigger cannot count itself. The
harness should observe at least 99 of those 100 attempts.

Distribute the deliberate sequences across these cases:

1. Hold the trigger without moving, then release: expect `NONE`.
2. Hold, move at least 120 points left, release: expect `LEFT`.
3. Hold, move at least 120 points right, release: expect `RIGHT`.
4. Hold, move mostly vertically, release: expect `NONE`.
5. Repeat with quick and slow holds.

Repeat the minimum matrix with:

- a built-in trackpad and one external mouse or trackpad;
- Finder, Chrome, and VS Code in normal windows;
- at least one full-screen application;
- one sleep/wake cycle while the harness remains open;
- Caps Lock and `--trigger right-option`.

If the harness has not reached its observed target after the planned physical
attempts, stop and record the last printed count as a miss. Also record any
`event tap timed out and was re-enabled` warning and verify that the next
sequence starts and ends normally rather than remaining stuck.

Use this evidence table for every run:

| Run label | Trigger | Intended | Observed | LEFT / RIGHT / NONE | Pointer events | Median callback | Recoveries | Stuck state | OS/app side effects |
| --- | --- | ---: | ---: | --- | ---: | ---: | ---: | --- | --- |
| Example only | Caps Lock | 100 | 100 | 30 / 30 / 40 | 824 | 4.20 ms | 0 | No | Caps Lock toggled |

Do not treat the example row as real evidence.

Record false starts, missing releases, permission failures, and whether Caps Lock
changes typing state. Finish the spike in GitHub issue #1 with one decision:

- **GO** — public APIs reliably detect the intended physical hold.
- **ADJUST** — the approach works only with a different trigger or interaction.
- **STOP** — a safe, supportable global-input path is not viable.

The Trello gate additionally requires at least 99/100 observed sequences, no
stuck state, and median callback latency below 25 ms on the test Mac. A green CI
build proves only that the harness compiles and its deterministic tests pass; it
does not prove those physical-device criteria.
