# Wheel menu-bar shell

`wheel-app` is the first production-facing native interface for Wheel. It is a
macOS 14 SwiftUI menu-bar app with a separate dashboard window.

The shell is intentionally honest about the current product boundary:

- global gesture input is live and listen-only;
- Input Monitoring onboarding and recovery are implemented;
- pause, disable, wake recovery, and input calibration are implemented;
- one app-level lifecycle coordinator owns launch, activation, wake, and shutdown;
- context capture and restoration are visible as **not connected**;
- recognizing LEFT or RIGHT does not mutate history or claim navigation success.

The separate `wheel-input-diagnostics` executable remains the evidence tool for
SPIKE-002. The product shell does not replace its physical test matrix.

## Run the app

Use macOS 14 or newer with the full Xcode toolchain selected:

```bash
swift build --product wheel-app
swift run wheel-app
```

Wheel launches as an accessory app and places its icon in the menu bar. Open the
menu to see live status or press **Open Wheel** for the full dashboard. The
listen-only monitor starts with the application; opening either surface does not
start another runtime or register another wake observer.

The first launch normally shows **Needs Permission**:

1. Press **Request Access** once.
2. If macOS does not grant access immediately, press **Open Privacy Settings**.
3. Enable the process that hosts Wheel. A `swift run` launch may be attributed to
   Terminal; an Xcode launch may be attributed to Xcode.
4. Return to Wheel and press **Check Again** if the status has not refreshed.

Wheel never loops the system prompt automatically. When access is missing or
revoked, it stops the event tap before updating the UI.

## Try gesture feedback

The default trigger is **Right Option**:

1. Confirm the status is **Ready**.
2. Hold the right Option key.
3. Move the pointer left or right.
4. Release the key.

The interface shows the recognized direction and explicitly says that context
restoration is not connected. Short or strongly vertical movement is reported as
ignored rather than being forced into LEFT or RIGHT.

The gesture card also shows a matching-signal count and the latest `DOWN` or `UP`
edge. This makes a successful trigger observation visible even when the pointer
movement is too short to become a gesture. While the trigger is held, both the
menu-bar item and the in-app status pill say **Trigger Held** and use a distinct
symbol. Recovery, pause, disable, configuration changes, and sleep/wake clear the
edge so the interface never leaves a stale `DOWN` indication.

The Input screen can change the trigger, minimum horizontal distance, and
horizontal-dominance ratio. Changing calibration safely replaces the running
monitor; queued callbacks from the previous monitor generation are ignored.

## Visible states

| State | Meaning |
| --- | --- |
| `Starting` | The app has not finished reconciling runtime state. |
| `Disabled` | Wheel is off and observes no global input. |
| `Needs Permission` | Input Monitoring is unavailable; the monitor is stopped. |
| `Ready` | The listen-only event tap started successfully. |
| `Paused` | Wheel remains enabled but observes no global input. |
| `Error` | The event tap or configuration failed; the message is shown in the UI. |

Color is supplementary. Every state includes text and a distinct SF Symbol.

## Deterministic UI fixtures

Fixture launches render named UI states without checking permission or creating a
native event tap. They are intended for visual review and future screenshot tests:

```bash
swift run wheel-app --fixture disabled
swift run wheel-app --fixture needs-permission
swift run wheel-app --fixture ready
swift run wheel-app --fixture paused
swift run wheel-app --fixture error
```

The equivalent `--fixture=ready` form is also accepted. Controls are disabled in
fixture mode so visual review cannot accidentally start global monitoring.

## Current limitation

This is a usable interface and input-status surface, not a complete global
Back/Forward utility yet. Stable native context identity, capture, suppression of
Wheel-originated activations, and truthful restoration results must land before
the interface can move through real app/window history.
