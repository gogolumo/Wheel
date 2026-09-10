# M1 Candidate Trigger Conflict Spike

This spike compares Caps Lock, Right Option, and an auxiliary mouse button as
possible Wheel triggers. It measures observability and user-visible conflicts;
it does not choose a production trigger from code alone.

The harness uses a listen-only Core Graphics event tap. Native key and button
behavior remains active so the test exposes conflicts instead of hiding them.
It never posts, rewrites, or suppresses input.

## Public API boundary

The implementation listens for Core Graphics
[`otherMouseDown`](https://developer.apple.com/documentation/coregraphics/cgeventtype/othermousedown)
and `otherMouseUp` events, then reads
[`mouseEventButtonNumber`](https://developer.apple.com/documentation/coregraphics/cgeventfield/mouseeventbuttonnumber).
It does not use a private driver API or assume that every mouse exposes the same
button mapping.

## Build first

Run from the repository root on macOS 14 or newer:

```bash
swift test
swift build --product wheel-input-spike
```

Grant Input Monitoring to the host application when macOS requests it. If the
permission changes, restart Xcode or the terminal before collecting evidence.

## Run each candidate

Use aggregate mode for scored runs:

```bash
swift run wheel-input-spike \
  --trigger caps-lock \
  --sequences 30 \
  --label "caps-lock-mixed-apps"

swift run wheel-input-spike \
  --trigger right-option \
  --sequences 30 \
  --label "right-option-mixed-apps"

swift run wheel-input-spike \
  --trigger mouse-side-button \
  --mouse-button 3 \
  --sequences 30 \
  --label "external-mouse-button-3-mixed-apps"
```

Core Graphics commonly numbers auxiliary buttons from 3 upward, but hardware
and remapping software can change what Wheel receives. To discover an emitted
number, start a short verbose diagnostic and press the available side buttons:

```bash
swift run wheel-input-spike \
  --trigger mouse-side-button \
  --mouse-button 3 \
  --verbose-events \
  --sequences 2 \
  --label "button-number-discovery"
```

The diagnostic prints every observed auxiliary button number and marks whether
it matches the configured number. Stop it with Control-C if the selected button
does not emit a complete sequence. Do not use verbose mode for latency evidence.

If no auxiliary-button events appear, record that result. Do not infer that the
mouse lacks buttons: its driver may translate them into navigation or keyboard
events before the session event tap sees them.

## Thirty-action matrix

Run 30 deliberate press/move/release actions for each available candidate.
Balance LEFT, RIGHT, and below-threshold NONE attempts. Distribute them across:

1. Finder in a normal window.
2. Chrome in a normal window.
3. VS Code in a normal window.
4. One full-screen application.
5. Both the usual and one alternate keyboard layout for keyboard candidates.
6. Five actions after a sleep/wake cycle while the harness remains open.

Split modifier trials between the built-in keyboard and one external keyboard
when both are available. Test the mouse candidate with the actual external
device that exposes the button. Use generic labels such as `built-in-keyboard`
or `external-usb-mouse`; never record a serial number or account-specific name.

## Evidence table

| Candidate | Device class | App/state | Intended | Observed | Wrong direction | Missing release | Native side effect | Recoveries | Median callback |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: |
| Example only | Built-in keyboard | Finder/windowed | 5 | 5 | 0 | 0 | Caps Lock toggled | 0 | 3.50 ms |

The example is not project evidence. Record every native side effect, including
Caps Lock state changes, Option-modified application behavior, browser Back,
Mission Control actions, or vendor-driver overlays.

Because this harness is deliberately listen-only, it cannot prove that a native
side effect can be safely suppressed. A destructive or routine conflict rejects
that candidate for the current gate unless a separate, permission-reviewed
suppression spike is approved.

## Decision

Finish GitHub issue #3 with one evidence-backed result:

- **GO** — at least one candidate has reliable press/release semantics and no
  destructive conflict; document its remaining conflict policy and fallback.
- **ADJUST** — observability works, but Wheel should use a configurable chord,
  hold shortcut, or a different default.
- **STOP** — every candidate is ambiguous, unavailable, or routinely conflicts
  with normal system/application behavior.

Do not claim broad hardware compatibility from one Mac. This spike only decides
whether the project has a supportable path into the next feasibility gate.
