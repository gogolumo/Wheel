# Wheel brand integration QA

The brand board is a visual reference. Production masters are authored geometry,
not cropped board pixels. Recreate the assets on macOS with:

```bash
swift -warnings-as-errors scripts/generate-brand-assets.swift
```

## Asset evidence

- [x] SVG masters parse as XML and use four equal radial segments plus a core.
- [x] Ten iconset PNGs decode at their required dimensions with transparent
  corners and an opaque core; every raster is rendered directly from geometry.
- [x] Visual inspection of 16, 32, 64, 128 and 512 px, plus enlarged 16/32 px
  pixels, confirms that the core and four separate segments remain recognizable.
- [x] The 18 pt monochrome template preserves the silhouette on light and dark
  review surfaces; runtime sets `NSImage.isTemplate = true`.
- [x] Five runtime PDFs and the 1024 px app icon decode in focused tests.
- [x] Repeated generation on the same SDK produces identical asset hashes.

See the actual [asset review sheet](../Brand/Previews/WheelAssetReview.png).
It is an asset contact sheet, not a Dock or Finder screenshot.

## Application evidence

Validated locally on macOS 26.6.2 with Swift 6.3.3:

- [x] `scripts/bootstrap-check.sh`: debug/release builds with warnings as errors,
  **211 tests with zero failures**, and the domain demo.
- [x] Module boundary, packaging shell syntax and process ownership checks.
- [x] The CI packaging/installation guard matrix run against isolated temporary
  paths: signature, install, update, smoke launch, locks, malformed/foreign/running
  targets, uninstall, and missing-brand rejection.
- [x] The installed bundle resolves and decodes its own resources after relocation.
- [x] The built ICNS expands back into all ten iconset sizes.
- [x] `NSWorkspace.icon(forFile:)` resolves the installed app's actual icon.
- [x] The installed executable renders **68 production component images** in
  isolated fixture mode, including Light/Dark and accessibility variants.

The build metadata identifies version `0.1.0`, build `1`. Launch smoke uses the
existing permission-free fixture mode; it does not prove physical Option input.
Spotlight indexing of the temporary installation is pending/unavailable.

| Visual evidence | Provenance |
| --- | --- |
| [Resolved application icon](../Brand/Previews/WheelResolvedAppIcon.png) | Native `NSWorkspace` icon lookup for the installed `.app`; no Finder window capture |
| [Status label Light](assets/readme/menu-status-label-light.png) / [Dark](assets/readme/menu-status-label-dark.png) | Actual `WheelMenuBarLabel`, without desktop/menu-bar chrome |
| [Menu popover](assets/readme/menu-bar.png) | Actual menu view with synthetic state and the opaque accessibility fallback |
| [Overlay](assets/readme/wheel-overlay.png) | Actual overlay view with synthetic identities/background |
| [About Light](assets/readme/settings-about-light.png) / [Dark](assets/readme/settings-about.png) | Actual About detail component with metadata from the packaged app |

The local CI harness used canonical temporary paths and ad-hoc signing for its
copied `sleep` helper. The latter is included in CI for compatibility with newer
macOS; production signing and process guards retain their existing behavior.

Use the documented build and installer, with fresh temporary destinations:

```bash
bash scripts/build-app.sh /tmp/wheel-brand-build
bash scripts/verify-app.sh /tmp/wheel-brand-build/Wheel.app
/tmp/wheel-brand-build/Wheel.app/Contents/MacOS/Wheel --verify-brand-resources
bash scripts/install-app.sh /tmp/wheel-brand-build/Wheel.app /tmp/wheel-brand-install/Wheel.app
/tmp/wheel-brand-install/Wheel.app/Contents/MacOS/Wheel --verify-brand-resources
bash scripts/smoke-app.sh /tmp/wheel-brand-install/Wheel.app
/tmp/wheel-brand-install/Wheel.app/Contents/MacOS/Wheel --render-fixtures /tmp/wheel-brand-fixtures
```

The resource audit starts with isolated fixture state before native input or
application capture. It requires packaged images to resolve inside that app's
`Contents/Resources/Wheel_WheelApp.bundle`. A missing packaged bundle must fail
even while the development `.build` resources exist. The verifier enforces the
new payload for `WheelBrandResourceVersion=1`; an older verified bundle remains
a valid upgrade target.

Production component exports use synthetic application identities and hidden,
non-key windows. Settings exports contain actual detail views; menu popovers
use the real opaque accessibility fallback. Status label exports use the actual
template label in Light/Dark. They prove image loading and view composition,
not live menu-bar vibrancy, native sidebar/chrome or global input behavior.

## Physical checks

Wheel keeps `LSUIElement=true` and the accessory activation policy. Normal
runtime intentionally has no Dock or Cmd+Tab entry. Creating such entries
would change behavior beyond this branding task.

These desktop checks require a user's Mac and remain unclaimed:

- [ ] Finder / Applications, Spotlight and Get Info show the packaged icon after
  installation and icon-cache refresh.
- [ ] The live status icon remains legible against Light/Dark menu bars.
- [ ] Settings sidebar/header fits with native chrome; keyboard navigation and
  VoiceOver announce status and controls correctly.
- [ ] Real desktop backgrounds preserve icon and overlay contrast.
- [ ] Existing Option trigger, release-to-switch and pinned applications work
  with Input Monitoring enabled, including Reduce Motion and Increase Contrast.

Offscreen images are not substitutes for these checks. Existing native input,
pin persistence and history tests remain the automated regression evidence.
