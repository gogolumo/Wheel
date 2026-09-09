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

The monitor is created with `CGEventTapOptions.listenOnly`. It does not suppress,
rewrite, or post input events. Caps Lock may still toggle normally during this
experiment.

## Test protocol

Run each case at least 20 times:

1. Hold the trigger without moving, then release: expect `NONE`.
2. Hold, move at least 120 points left, release: expect `LEFT`.
3. Hold, move at least 120 points right, release: expect `RIGHT`.
4. Hold, move mostly vertically, release: expect `NONE`.
5. Repeat with quick and slow holds and after sleep/wake.
6. Compare Caps Lock with `--trigger right-option`.

Record false starts, missing releases, permission failures, and whether Caps Lock
changes typing state. Finish the spike in GitHub issue #1 with one decision:

- **GO** — public APIs reliably detect the intended physical hold.
- **ADJUST** — the approach works only with a different trigger or interaction.
- **STOP** — a safe, supportable global-input path is not viable.
