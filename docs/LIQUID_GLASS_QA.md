# Liquid Glass UI review

This is the manual review plan for `feat/liquid-glass-ui`. The approved composition
is documented in [DESIGN.md](../DESIGN.md) and the
[Liquid Glass hero](../DesignPreview/LIQUID_GLASS_HERO.md). Automated checks can
verify fixture state, persistence isolation, panel configuration, and existing
navigation invariants. They cannot establish desktop legibility, focus, real
Input Monitoring behavior, full-screen presentation, or display positioning.

**Physical macOS checks below are pending.** An unchecked item has not been
verified. Record macOS version, Mac/display arrangement, appearance, accessibility
preferences, and result when completing a check. Keep evidence local and use
synthetic data for any shared visual evidence; never upload private activity,
window titles, document contents, or screenshots of a user's work.

## Deterministic visual fixtures

Launch one fixture at a time; quit Wheel between launches. These use the production
overlay and application presentation components with explicitly synthetic names,
fixed identities/dates, in-memory history, and in-memory isolated settings/pins.
The normal runtime never seeds sample applications. Fixture launches skip Input
Monitoring checks/requests, event-tap creation, and application capture. The
synthetic identity label must remain visible. Application icon fallbacks in these
fixtures are intentional: real runtime uses local application icons.

```bash
cd ~/Documents/Wheel/Wheel
swift run wheel-app --visual-fixture empty
swift run wheel-app --visual-fixture two
swift run wheel-app --visual-fixture four
swift run wheel-app --visual-fixture six
swift run wheel-app --visual-fixture eight
swift run wheel-app --visual-fixture twelve
swift run wheel-app --visual-fixture selected-running
swift run wheel-app --visual-fixture selected-terminated
swift run wheel-app --visual-fixture unavailable-pin
swift run wheel-app --visual-fixture mixed-pins
```

`--visual-fixture=<name>` is also accepted. A valid visual fixture takes precedence
over `--overlay-fixture` and `--fixture`; equals options take precedence over named
options, matching the legacy parsers. An unknown name is not a fixture and should
not be used for permission-free review.

| Fixture | Inspect |
| --- | --- |
| `empty` | Clear empty guidance; eight empty sectors; no misleading app detail or error |
| `two`, `four`, `six`, `eight`, `twelve` | Exact population/segmentation; readable labels; coherent shell/hub; no clipped sectors, overlaps, or debug counts |
| `selected-running` | Selected first sector, structural outline/marker, restrained lift; Running and switch guidance |
| `selected-terminated` | Selected first sector; Recently closed, reopen marker/guidance; no oversized warning |
| `unavailable-pin` | Missing application remains at sector 3; pin and Unavailable state; no release-to-open promise |
| `mixed-pins` | Eight apps; fixed pins at sectors 2 and 6; one terminated pin; dynamic apps appear once |

All six legacy status fixtures remain supported:

```bash
swift run wheel-app --fixture disabled
swift run wheel-app --fixture needs-permission
swift run wheel-app --fixture ready
swift run wheel-app --fixture trigger-held
swift run wheel-app --fixture paused
swift run wheel-app --fixture error
```

All four legacy overlay fixtures remain supported:

```bash
swift run wheel-app --overlay-fixture held
swift run wheel-app --overlay-fixture left
swift run wheel-app --overlay-fixture right
swift run wheel-app --overlay-fixture none
```

Legacy fixtures now use empty isolated history/pins rather than reading the user's
saved applications. Their existing status and gesture states remain available.

### Offline visual artifact export

The opt-in fixture renderer exports only the SwiftUI fixture subtree over synthetic
gradient backdrops. It does not capture a screen, inspect a wallpaper, or export
real application activity. It deliberately uses sample placeholder symbols while
normal runtime continues using real local application icons.

```bash
swift run wheel-app --render-fixtures /tmp/wheel-liquid-glass-fixtures
```

The export matrix contains 66 images:

| Surface/state | PNGs |
| --- | ---: |
| Ten overlay fixtures in Light and Dark appearance | 20 |
| Selected-running overlay with four accessibility variants in each appearance | 8 |
| Mixed-pins overlay over bright, dark, busy, and plain synthetic backgrounds in each appearance | 8 |
| Actual content components for eight Settings sections in each appearance | 16 |
| Six legacy menu/status fixtures plus a recent-application fixture in each appearance | 14 |

Accessibility exports use the additive `WheelAccessibilityReview` environment to
exercise Reduce Motion, Reduce Transparency, Increase Contrast, and Differentiate
Without Color fallbacks. It can enable a fallback and never disables a real system
preference. Record the host's actual preferences when comparing baseline images;
an enabled host preference can also affect the baseline.

Settings exports render the actual detail components in never-shown non-key fixture windows; filenames include `content`. Native sidebar and title-bar rendering remain physical checks because AppKit split-view layers can be absent in offscreen bitmaps. Menu filenames include `opaque-fallback`: they exercise the real Reduce Transparency fallback because native glass shaders can corrupt offscreen bitmaps. No fixture window is ordered on screen.

Renderer/build validation is recorded in the implementation report. Review the
artifacts for geometry, state clarity, label density, and accessibility fallback
structure; exported bitmaps cannot prove native backdrop rendering, focus, or input
behavior. Physical wallpaper and platform checks below remain necessary.

## Appearance and accessibility — pending physical review

For each row, inspect empty, twelve-item, selected running, selected terminated,
unavailable pin, and mixed fixtures. Check menu bar and Settings as well as the
overlay. Inspect actual app icons separately in normal runtime. Assess text,
selection, unavailable state, pins, outline, hub, detail panel, and all edges.

| Wallpaper | Light appearance | Dark appearance |
| --- | --- | --- |
| Bright | [ ] Pending | [ ] Pending |
| Dark | [ ] Pending | [ ] Pending |
| Busy/high-detail | [ ] Pending | [ ] Pending |
| Plain/low-detail | [ ] Pending | [ ] Pending |

- [ ] Default accessibility preferences: material remains legible; selected apps
  have structural feedback, restrained accent, and no neon or continuous shimmer.
- [ ] Reduce Transparency: opaque semantic surfaces; labels, pins, and state remain
  legible; glass paths do not leak through the fallback.
- [ ] Increase Contrast: stronger visible outlines; secondary text remains legible
  in Light and Dark appearance.
- [ ] Reduce Motion: spatial entrance/selection scale and translation are removed;
  selection remains immediate and clear through outline/contrast/marker.
- [ ] Differentiate Without Color: selected state remains obvious without accent
  color; pins and closed/unavailable states still communicate through symbols/text.
- [ ] All four preferences enabled together: no hidden information, overlap,
  unreadable foreground, or missing selected state.
- [ ] Keyboard navigation in Settings and menu: native controls, focus visibility,
  sidebar selection, pickers, pin choices, and actions are usable.
- [ ] VoiceOver: app names, run state, pinned/selected state, and read-only gesture
  guidance are meaningful; decorative rim/segments are not redundant controls.

The fallback can also be compiled explicitly on a newer toolchain:

```bash
swift build --scratch-path /tmp/wheel-material-build --product wheel-app \
  -Xswiftc -warnings-as-errors -Xswiftc -DWHEEL_FORCE_MATERIAL
/tmp/wheel-material-build/debug/wheel-app --render-fixtures /tmp/wheel-material-fixtures
```

This verifies the fallback source path, not OS-specific physical behavior.

Test on a macOS 14 fallback host when available, and a macOS 26/native-glass host
when available. SDK availability checks and successful compilation do not prove
either rendered appearance. Record unavailable host coverage explicitly.

## Native overlay and input — pending physical review

Use normal runtime, not fixtures. Confirm Input Monitoring for the hosting process
(Terminal/Xcode during `swift run`, or Wheel for the installed bundle).
Accessibility and Screen Recording are not required for this application-only
implementation. Visit several normal applications to populate real history.

- [ ] Hold the configured trigger long enough to show the new wheel. Entrance is
  approximately 160 ms; release feedback is immediate and dismisses cleanly.
- [ ] A short tap remains overlay-free. Left Option remains inactive when Right
  Option is configured. Existing trigger settings/calibration still apply.
- [ ] Overlay appears above normal application windows and remains nonactivating,
  non-key, and click-through. It does not unnecessarily capture mouse/keyboard input.
- [ ] Hold the trigger in an active text field without selecting an application;
  the source application remains frontmost, then continues accepting typed input.
- [ ] Select each populated sector using the existing pointer displacement mapping;
  hover/selection and release target agree, including left/right boundaries.
- [ ] The context detail surface stays tied to the wheel and inside the visible
  display frame. Nothing is clipped on a small display or with a visible Dock.
- [ ] Repeat in a full-screen application/Space; presentation, dismissal, focus,
  and input behavior remain correct.
- [ ] Repeat with multiple physical displays, scaled resolutions, different Dock
  positions, and a changed display arrangement while the wheel is visible. Record
  the selected screen. The current main-screen placement policy is preserved;
  this change does not claim pointer-display selection.
- [ ] Pause, disable, permission loss, event-tap recovery, trigger configuration
  replacement, sleep/wake, and quit cancel pending/visible overlays without stale
  result content or a stuck held state.
- [ ] Repeat rapid trigger/release cycles; no overlapping active gesture or stale
  dismissal affects the newest overlay.
- [ ] Compare cold/warm presentation with the prior build on the same Mac. No
  noticeable delay, persistent animation, or sustained GPU activity after dismissal.

## Pins, history, and restoration — pending physical review

- [ ] Pin, replace, move, and unpin real applications in Settings; exact sectors and
  badges match stored assignments and survive a restart.
- [ ] Reduce direction count so a pin becomes hidden, then restore the count;
  hidden pins return to their original positions without losing assignments.
- [ ] Dynamic history fills unpinned slots without duplicating a pinned app; visible
  item count and direction count preserve the existing budget.
- [ ] Activate a running app from the wheel; it switches through the existing path
  and no fake window/tab/document preview is shown.
- [ ] With remembering closed apps enabled, terminate a captured app and reopen it
  from the wheel. Recently closed styling and actual reopen behavior agree.
- [ ] Disable remembering closed apps; normal history behavior remains unchanged.
- [ ] Remove/uninstall a pinned test app: its pin remains visible and unavailable;
  the UI does not promise Open/Switch/Reopen. The inherited release behavior can
  still attempt activation and report failure. Changing that gesture semantic is
  outside this presentation work; pin retention and failed restoration stay intact.
- [ ] Failed/cancelled/unavailable/permission-denied restoration does not advance
  domain history; Wheel-restored context does not append independent work.
- [ ] Confirm LEFT = previous global context and RIGHT = next in canonical domain
  coverage; Back preserves forward history, independent new work replaces it,
  and only one GestureSession can be active. Automated domain tests/`wheel-demo`
  are evidence for these invariants; do not infer deeper native restoration support.
- [ ] Run fixtures after real use, change fixture layout/pins, then quit and return
  to normal runtime. Real history, settings, and pins remain unchanged.

## Settings, menu, and packaging — pending physical review

- [ ] General, Wheel Layout, Applications, History, Appearance, Permissions,
  Advanced, and About are easy to reach. Engineering counters/calibration remain
  under Advanced and do not dominate everyday UI.
- [ ] Menu answers readiness, trigger, pause/resume/enable, permission attention,
  Settings, and Quit in a compact native surface. Opening Settings works reliably.
- [ ] Permission copy accurately requests Input Monitoring only; Check Again and
  real permission recovery work after grant/revocation.
- [ ] Build/install `Wheel.app`, launch through Finder/Spotlight/Launch Services,
  and verify menu visibility, accessory/Dock behavior, and distinct TCC attribution.
- [ ] Installed bundle launches independently of Terminal and preserves packaging,
  signature/metadata verification, safe replacement, and local persistence.

## Automated evidence

Root validation records exact results for these commands in the implementation
report. Leave CI/physical outcomes unclaimed until they have actually completed.

```bash
bash scripts/bootstrap-check.sh
swift test -Xswiftc -warnings-as-errors
swift build -Xswiftc -warnings-as-errors
swift build -c release -Xswiftc -warnings-as-errors
bash scripts/build-app.sh
bash scripts/verify-app.sh dist/Wheel.app
```

`WheelVisualFixtureTests` covers argument forms/precedence, explicit synthetic-only
data, exact 0/2/4/6/8/12 populations, selected run states, unavailable persistent
pins, fixed/dynamic mixtures, deterministic identities, launch isolation, legacy
fixture preservation, and absence of permission/input/capture/activation calls.
Existing domain, history, pins, gesture, lifecycle, and panel suites remain required.

`WheelSettingsLayoutTests` hosts the full production Settings split view in hidden,
titled fixture windows. It checks every section at default and resized viewports,
and verifies that twelve application assignments scroll to the bottom inside the
window. This catches native split-view intrinsic-height overflow that isolated
detail-component PNGs cannot detect. It does not establish live window chrome,
keyboard/focus behavior, or physical desktop accessibility results.
