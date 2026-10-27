# M1 Global Input Spike

This executable tests Wheel's riskiest early assumption: whether a public,
listen-only macOS input path can reliably observe a held trigger and pointer
movement without intercepting normal input.

It is a diagnostic, not production gesture handling. A successful compile does
not prove that Caps Lock is viable; that decision requires repeated testing on a
real Mac.

## Verify the signed physical-test build

The default local bundle is ad-hoc signed and does not satisfy SPIKE-001's
signed-environment requirement. Build with a Keychain signing identity, then
run the privacy-safe verifier before checking `signed-build` in the final gate:

```bash
WHEEL_CODESIGN_IDENTITY="Apple Development: …" bash scripts/build-app.sh
bash scripts/verify-spike-signed-build.sh dist/Wheel.app \
  --summary-json ../spike-001-signed-build.json
```

The verifier prints only `PASS` or a generic failure. It does not print the
certificate identity, Team ID, account name, or application path. A passing
result verifies signature integrity, the Wheel bundle identifier, a non-ad-hoc
signing authority anchored to Apple's code-signing trust chain, and that the
bundle's stamped `WheelSourceRevision` matches
the repository's current `HEAD`. It also requires the expected non-symbolic
executable and icon, executable and bundle-identifier metadata, and the complete
non-symbolic Wheel brand resource set, so an incomplete or structurally foreign
signed bundle fails closed. The bundle must also declare the macOS application
package type (`APPL`) and supported Wheel brand-resource contract version 1;
foreign package types and incompatible resource layouts are rejected without
printing their values. `LSUIElement` must remain `true`, binding the test
to Wheel's non-activating background/menu-bar application rather than a
foreground substitute. An optional
explicit revision pin must also
match `HEAD`; it cannot redirect verification to another clean, published
commit. The same revision must be the configured
upstream branch head, so a detached, unpushed, or locally diverged commit cannot
be presented as reviewable evidence. Fetch and fast-forward the test branch
immediately before building. The verifier also fails when the repository has
staged, unstaged, or untracked files, because `build-app.sh` compiles the
checkout and a dirty tree could otherwise place unreviewed code in a bundle
stamped with `HEAD`. It never prints branch names, revisions, or dirty
filenames. These checks prevent stale, unpublished, or locally modified signed
builds from satisfying the precondition; they prove nothing about the remaining
physical matrix. The optional summary is created atomically and never
overwrites an existing file. It contains only the public source revision and
allowlisted contract results; certificate identity, Team ID, account data,
local paths, and hardware identifiers are excluded. Attach this JSON alongside
the four physical run exports.

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
name, document title, URL, or other personal data. Both interfaces reject labels
longer than 64 characters, line breaks, path/URL punctuation, and leading or
trailing whitespace. The process prints live
sequence counts and median event-callback latency, then emits an aggregate
summary after the requested number of observed sequences. Pointer movement is
counted but not printed by default: synchronous console output for every move
can create event-tap backpressure and invalidate the latency measurement.

The optional JSON file contains aggregate counters, the configured classifier
and latency thresholds, and their threshold checks. A mouse-button run also
records the configured button number. It never records coordinates, titles,
paths, typed content, or hardware identifiers. It still requires manual review
because the harness cannot know the physical-attempt count, stuck-state result,
or native side effects.
After the planned physical attempts, press Control-C if the observed target was
not reached. The harness prints the partial summary and writes the JSON before
exiting with status 130, preserving evidence of the missed sequence.

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

After exporting the scored runs, make the automated batch check require both
keyboard candidates. This prevents several files for one trigger from being
mistaken for the complete comparison:

```bash
run_labels=(caps-lock-built-in caps-lock-external right-option-built-in right-option-external)
scenarios=(finder chrome vscode full-screen sleep-wake timeout-recovery)
reviews=(event-order intended-vs-observed stuck-state side-effects)
scenario_args=()
review_args=()
for run_label in "${run_labels[@]}"; do
  for scenario in "${scenarios[@]}"; do
    scenario_args+=(--attest-run-scenario "$run_label" "$scenario")
  done
  for review in "${reviews[@]}"; do
    review_args+=(--attest-run-review "$run_label" "$review")
  done
done

swift run wheel-evidence-check \
  --profile spike-001-final \
  --attempt-count caps-lock-built-in 100 \
  --attempt-count caps-lock-external 100 \
  --attempt-count right-option-built-in 100 \
  --attempt-count right-option-external 100 \
  "${scenario_args[@]}" \
  "${review_args[@]}" \
  --attest-environment clean-account \
  --attest-environment signed-build \
  --recording-duration-seconds 120 \
  --record-decision go \
  spike-001-*.json
```

`--profile spike-001-final` expands to the recorded trigger, independent-run,
named-slot, 100-sequence, 99/100 reliability, direction-coverage, and 25 ms
median-latency requirements. It intentionally does not supply any
`--attempt-count`: the operator must attest each physical run explicitly.
The profile cannot be mixed with individual requirement options, preventing a
partially overridden gate from looking canonical.

Each `--attest-run-scenario` is also an operator attestation, not collected
telemetry. The fixed allowlist records only whether the required test setting
was exercised; it does not store window titles, URLs, document contents, typed
text, or application activity. The canonical profile fails closed if any of
Finder, Chrome, VS Code, full-screen, sleep/wake, or event-tap timeout recovery
is omitted for any of the
four required run labels. These flags do not prove the scenario occurred, so
the recording and manual review remain mandatory.

Each `--attest-run-review` confirms only that the operator reviewed that run
for the named category: `press -> move -> release` event order, intended versus
observed directions, stuck state, or native side effects. Aggregate event
counts cannot establish event order. `--recording-duration-seconds 120`
confirms only that the required recording is at least two minutes long. Neither
flag records a result, asserts `PASS`, or turns the automated check into a `GO`
decision; the recording, observations, and final decision must still be
reviewed manually.

Record `--record-decision go` only after the recording and written observations
have been reviewed. The canonical gate fails closed when the decision is absent,
or when the recorded outcome is `adjust` or `stop`; the flag is an operator
decision, not an automated inference from the aggregate JSON.

The two `--attest-environment` flags confirm that the matrix was executed from
a clean macOS account with the signed spike build required by SPIKE-001. They
do not inspect the account, certificate, username, team identifier, or hardware.

The two-run minimum prevents a single export per trigger from being presented as
the built-in plus external-device comparison. Use unique privacy-safe run labels
for those independent runs. This command still checks only aggregate coverage
and evidence integrity. The named run requirements ensure that each expected
privacy-safe matrix slot exists and is bound to the intended trigger, but they
cannot identify hardware or prove which device was used. Each `--attempt-count`
is an operator attestation, not telemetry: the checker requires it for every
named slot, verifies the declared 100-attempt target, and rejects an impossible
tally lower than the observed sequence count. It also requires every attested
export's configured `sequenceTarget` to equal 100, so a shorter run cannot be
paired with a larger manual attestation. The per-run missed-attempt limit
independently enforces the 99/100 reliability
criterion from the attested attempt count and observed sequence count.
Device/application coverage,
intended versus observed directions, stuck state, and side effects still require
manual review.

The checker identifies inputs only as `Evidence file #1`, `#2`, and so on. It
does not echo file paths or raw filesystem/decoder errors into terminal or CI
logs, because those diagnostics can contain account names or private folders.
It also rejects unrecognized top-level JSON fields instead of silently ignoring
them. This keeps app names, window titles, paths, URLs, or other unreviewed data
from being attached to an otherwise valid aggregate export.

For one final SPIKE-001 run, apply the explicit acceptance thresholds recorded
by the gate:

```bash
swift run wheel-evidence-check \
  /tmp/wheel-spike-001-final.json \
  --expected-trigger right-option \
  --expected-sequence-target 100 \
  --minimum-observed 99 \
  --minimum-left 1 \
  --minimum-right 1 \
  --minimum-none 1 \
  --maximum-median-latency-ms 25
```

`--expected-sequence-target 100` rejects evidence produced by a shorter configured
run. `--minimum-observed` deliberately allows a valid interrupted 99/100 export
to pass the aggregate check. Neither option proves that exactly 100 physical
attempts were made: the operator must still report the deliberate-attempt tally,
misses, device/application coverage, stuck state, and native side effects.
The direction minimums also reject a file containing only LEFT, only RIGHT, or
only NONE results. They do not prove that the observed result matched the
operator's intended direction; that comparison remains part of the manual table.

If the harness has not reached its observed target after the planned physical
attempts, press Control-C and retain the partial JSON as evidence of the miss.
Also record any
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
