# Wheel menu-bar shell

`wheel-app` is the first production-facing native interface for Wheel. It is a
macOS 14 SwiftUI menu-bar app with a separate dashboard window.

The shell is intentionally honest about the current product boundary:

- global gesture input is live and listen-only;
- Input Monitoring onboarding and recovery are implemented;
- pause, disable, wake recovery, and input calibration are implemented;
- a click-through nonactivating HUD confirms trigger and gesture results over
  the current application;
- one app-level lifecycle coordinator owns launch, activation, wake, and shutdown;
- application-level capture is connected through public `NSWorkspace` lifecycle notifications;
- recently terminated applications remain eligible targets and can be relaunched;
- exact window/tab/folder/editor restoration is still not claimed.

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

The application-level branch presents recently visited apps around a radial Wheel.
Raw pointer displacement selects a sector while the trigger is held; releasing over
a populated sector activates a running app or relaunches a terminated one. Exact
window/tab/file restoration remains outside this slice.

The gesture card also shows a matching-signal count and the latest `DOWN` or `UP`
edge. This makes a successful trigger observation visible even when the pointer
movement is too short to become a gesture. While the trigger is held, both the
menu-bar item and the in-app status pill say **Trigger Held** and use a distinct
symbol. Recovery, pause, disable, configuration changes, and sleep/wake clear the
edge so the interface never leaves a stale `DOWN` indication.

After the trigger remains held for 180 ms, Wheel presents a compact HUD over the
current app. A shorter press stays entirely HUD-free. The HUD is a single
borderless nonactivating `NSPanel`: it cannot become key or main, ignores mouse
events, joins every Space, and is allowed alongside full-screen apps. Releasing the trigger after the HUD appears selects the populated radial sector,
shows the chosen application briefly, and dismisses the HUD. When no captured app
occupies the selected sector, the legacy LEFT / RIGHT / NONE feedback remains
available for diagnostics.

HUD placement uses the system's main-screen selection and never reads pointer
coordinates. If the display arrangement changes while the HUD is visible, the
same panel is recentered inside the newly selected screen's visible frame. The
screen-change observer is removed during shutdown. A second-display placement
policy remains deliberately unclaimed until it can be validated without
weakening Wheel's privacy boundary.

Pause, disable, permission loss, event-tap recovery, configuration replacement,
system sleep, wake, and termination cancel a pending presentation and dismiss a
visible HUD immediately. Before macOS sleeps, Wheel stops the event tap and clears
held-state; after wake it rechecks permission and creates a fresh monitor. This
prevents pre-sleep callbacks or a held trigger from leaking into the resumed
session. Presentation and dismissal are generation-guarded so an old gesture
cannot show or hide a newer one.

The Input screen can change the trigger, minimum horizontal distance, and
horizontal-dominance ratio. Changing calibration safely replaces the running
monitor; queued callbacks from the previous monitor generation are ignored.

## Visible states

| State | Meaning |
| --- | --- |
| `Starting` | The app has not finished reconciling runtime state, or monitoring is suspended until wake. |
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
swift run wheel-app --fixture trigger-held
swift run wheel-app --fixture paused
swift run wheel-app --fixture error
```

The `trigger-held` fixture renders one matching `DOWN` edge and the active gesture
state, including the floating HUD, without opening an event tap. The equivalent
`--fixture=ready` form is also accepted. Controls are disabled in fixture mode
so visual review cannot accidentally start global monitoring.

Overlay fixtures render the production HUD without checking permission or creating
an event tap:

```bash
swift run wheel-app --overlay-fixture held
swift run wheel-app --overlay-fixture left
swift run wheel-app --overlay-fixture right
swift run wheel-app --overlay-fixture none
```

The equivalent `--overlay-fixture=<state>` form is also accepted. Quit the fixture
from the menu-bar item or with Control-C when launched through `swift run`.

## Physical overlay check

Run the real app, confirm **Ready**, and check Right Option DOWN / LEFT / RIGHT /
NONE from Finder, Chrome, and VS Code. Repeat once in a full-screen Space. The
source application must remain frontmost and
an active text field must continue accepting input after the gesture. Left Option
must not present the HUD while Right Option is configured.

## Application history and radial Wheel

Application-level capture stores only serializable launch identity and timestamps:
bundle identifier when available, application URL as fallback, display name, and
run state. PID is transient and is never the persistent identity. The current app
is retained as the history pointer but is excluded from the destination ring.

Settings are persisted independently:

- **Visible apps**: 3...12, default 8.
- **Directions**: 2, 4, 6, 8, 10, or 12, default 8.
- **History capacity**: 10...200, default 50.
- **Remember closed applications**: on by default.

The current UI uses one radial ring, so it can show at most
`min(visible apps, directions)` destinations at once. The values remain separate
in the model so later paging/rings do not force history capacity to equal sector
count.

Application history is persisted locally in
`~/Library/Application Support/Wheel/application-history.json` for this vertical
slice. This does **not** claim completion of the release persistence ADR; the
project's release history store can still migrate behind its storage boundary.

## Manual application-level check

From the repository:

```bash
cd ~/Documents/Wheel/Wheel
git fetch origin
git switch feat/CTX-app-history-wheel
git pull --ff-only
swift build --product wheel-app
swift test
swift run wheel-app
```

Then activate Safari, Finder, Xcode, and another normal app. Hold Right Option
longer than 180 ms: the radial Wheel should show prior applications without
stealing focus. Change **Wheel → Directions** between 4, 6, and 8 and repeat.
Quit one captured application with Command-Q, invoke Wheel again, select its icon,
and verify macOS relaunches that application.

## Current limitation

This branch implements **APPLICATION_ONLY** capture and restoration. It does not
claim the previous window, browser tab, Finder folder, editor, scroll position, or
unsaved state. Those require the window-identity spike and adapter contracts.

The radial multi-direction selector is also a product-semantics experiment on this
stacked branch. The repository's established LEFT/RIGHT Back/Forward contract is
not silently superseded by this implementation; adopting radial selection as the
product grammar requires an explicit product/ADR decision.
