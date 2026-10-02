# Wheel menu-bar shell

`wheel-app` is the first production-facing native interface for Wheel. It is a
macOS 14 SwiftUI menu-bar app with a separate native Settings window.

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

To build and install a real app bundle on macOS 14+:

```bash
bash scripts/build-app.sh
bash scripts/install-app.sh
bash scripts/doctor-app.sh /Applications/Wheel.app
bash scripts/smoke-app.sh /Applications/Wheel.app
open /Applications/Wheel.app
```

The script builds the existing SwiftPM `wheel-app` product in release mode,
packages it with `CFBundleIdentifier=dev.gogolumo.Wheel`, `LSUIElement=true`
and a placeholder icon, and applies an ad-hoc local signature. The bundle runs
independently of Terminal. The builder stages and verifies the complete bundle
before replacing an earlier verified artifact, serializes builds per output
directory, and rolls back a failed replacement. It refuses symbolic-link and
unverified `Wheel.app` output targets instead of deleting them. Quit any
`swift run wheel-app` instance first.
`install-app.sh` refuses to replace a running Wheel, validates the bundle before
and after installation, stages the copy beside the destination, and restores the
previous installation if validation fails. Use it for updates as well as first
installation; plain `cp -R` can nest the new bundle inside an existing
`/Applications/Wheel.app`.
Build, install, diagnostics, smoke, and removal identify a running bundle by its
exact canonical `Contents/MacOS/Wheel` path, not just by the process name. An
unrelated executable also named `Wheel` is ignored, and smoke cleanup rechecks
ownership before sending a signal so it cannot terminate that process.
Run `scripts/doctor-app.sh` after installation to verify the bundle contract,
exact packaged source revision, code-signing identity, and current Spotlight
metadata. A fresh install may report Spotlight as pending until macOS indexes
the application; that informational state does not weaken bundle verification.
`smoke-app.sh` launches the verified bundle through Launch Services with the
deterministic `ready` fixture, confirms that the expected packaged executable
stays alive, and then terminates it. Fixture mode does not request Input
Monitoring or start the native event tap. This is an automated packaging check,
not evidence that the menu-bar item is visible or that Finder, Dock, TCC, the
overlay, or application relaunch behavior passed on a user's Mac.
macOS associates Input Monitoring with this app bundle separately from
Terminal/Xcode. The local signature is for development; distribution requires
Developer ID signing and notarization. A future rebuild may require granting
Input Monitoring again. The installed build can be removed safely after quitting Wheel with:

```bash
bash scripts/uninstall-app.sh /Applications/Wheel.app
```

The uninstaller refuses symbolic links, unrelated or malformed bundles, invalid
signatures, and running Wheel processes. Installation, update, and removal share
one per-directory lock so they cannot replace or delete the bundle concurrently.
It removes only the app bundle; local application history remains in Application
Support unless deliberately removed.

Wheel launches as an accessory app and places its icon in the menu bar. Open the
menu to see live status or press **Open Settings…** for configuration. The
listen-only monitor starts with the application; opening either surface does not
start another runtime or register another wake observer.

The first launch normally shows **Needs Permission**:

1. Press **Request Access** once.
2. If macOS does not grant access immediately, press **Open Privacy Settings**.
3. Enable the process that hosts Wheel. The installed bundle is **Wheel**;
   a `swift run` launch may be attributed to Terminal, and an Xcode launch to Xcode.
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

Engineering diagnostics live under **Settings → Advanced**: matching signals,
DOWN/UP edges, recognized gestures, event-tap recoveries, calibration, and current
capabilities. General shows runtime status and the trigger without metric cards.
The menu-bar item and Settings status still identify **Trigger Held**, and recovery,
pause, disable, configuration changes, and sleep/wake clear transient held state.

After the trigger remains held for 180 ms, Wheel presents the glass wheel over the
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

General can change the trigger. Advanced contains minimum gesture distance and
horizontal-dominance calibration. Changing calibration safely replaces the running
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

## Pinned applications

Settings → Applications includes assignments for every active radial
sector and a separate list of retained hidden pins. A slot can remain **Automatic** or point to a selected macOS `.app`
bundle.

Pinned and dynamic targets deliberately share one layout:

- a pinned application keeps its exact sector and is never displaced by recent
  history;
- unpinned sectors continue to fill from the existing application history;
- choosing an application that is already pinned moves that pin instead of
  creating a duplicate;
- replacing a slot removes only the previous application assigned to that slot;
- removing a pin immediately returns that sector to automatic history;
- pins are stored in `UserDefaults` and survive Wheel restarts and macOS
  logout/reboot;
- reducing the direction count hides out-of-range pins without deleting them;
  restoring the larger direction count brings those pins back.

The app picker accepts normal application bundles and rejects nested helper
applications. Persistent identity prefers the bundle identifier over the stored
path. When an application moves, Wheel asks Launch Services for its current URL.
Before using a stored path as a fallback, Wheel revalidates that it is still a
normal `.app` bundle and that its bundle identifier still matches the pin. A
missing, malformed, or replaced bundle is never exposed as a launch target. In
that case, the pinned sector remains visible as unavailable rather than silently
deleting the user's configuration.

The overlay marks pinned applications with a small pin badge. Running targets
are activated; installed but terminated targets are relaunched through the
existing `NSWorkspace` activation layer.

## Manual application-level check

From the repository:

```bash
cd ~/Documents/Wheel/Wheel
git fetch origin
git switch feat/liquid-glass-ui
git pull --ff-only
swift build --product wheel-app
swift test
swift run wheel-app
```

Then activate Safari, Finder, Xcode, and another normal app. Hold Right Option
longer than 180 ms: the radial Wheel should show prior applications without
stealing focus. Change **Settings → Wheel Layout → Directions** between 4, 6, and 8 and repeat.
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


## Liquid Glass presentation

The approved visual direction is implemented in production views; see
[DESIGN.md](../DESIGN.md). The ring uses real application destinations, a circular
hub, rounded annular sectors, thin optical edges, and a restrained selected lift.
A related right-hand panel shows only application name/icon, Running / Recently
closed / Unavailable, pin state, and release guidance. Because the HUD remains
click-through, pin changes stay in Settings. No window screenshot or app-specific
action is fabricated.

The bounded 820×520 pt panel reserves the actual ring and context-panel footprint;
it scales proportionally inside smaller visible screen frames. Its non-key,
nonactivating, status-bar-level, full-screen auxiliary, and single-panel lifecycle
contracts are unchanged. The existing main-screen placement policy remains in
place; this does not claim pointer-screen targeting.

Settings sections are General, Wheel Layout, Applications, History, Appearance,
Permissions, Advanced, and About. Appearance follows macOS rather than adding
presentation preferences to history/domain settings. Menu-bar content is a 300 pt
wide status/trigger/pause/permission/settings/quit surface with a real recent-app
row when available.

Native macOS 26 glass is compiler/runtime gated. macOS 14–25 uses native
Material with a restrained border/highlight/shadow fallback. Reduce Transparency
and Increase Contrast select opaque semantic surfaces; Reduce Motion removes
spatial movement and Differentiate Without Color strengthens structural selection.
No external dependency is required.

Legacy fixture launches now isolate history/settings/pins in memory. New explicit
`--visual-fixture` states and `--render-fixtures <directory>` exports exercise the
production view tree without permissions or application capture. See the
[fixture matrix and manual test checklist](LIQUID_GLASS_QA.md). Offscreen bitmaps
can flatten native materials and are not proof of physical desktop rendering.
