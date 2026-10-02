# Wheel production design system

Wheel's canonical native UI specification. The approved [Liquid Glass hero](DesignPreview/LIQUID_GLASS_HERO.md), [viewer](DesignPreview/liquid-glass-hero.html), and [prototype](DesignPreview/index.html) define the composition: one circular glass shell, rounded annular sectors, a deep circular hub, restrained selected lift, and a related right-hand application detail surface. This specification translates that direction into real application-level capabilities.

## Product boundary

Presentation consumes real `wheelSlots`, selection indices, pin assignments, application run state, and `WheelSectorLayout`. Sector zero and all angles retain their existing mapping. LEFT remains previous global context and RIGHT next; domain history, forward branches, failed restoration, one-session handling, permissions, privacy, and lifecycle remain authoritative in `PROJECT_RULES.md`. The existing radial experiment is preserved, not adopted as a new domain grammar. No rich window/tab previews or application-specific shortcuts are implied.

The gesture panel stays nonactivating and click-through. Its detail panel provides state and a release-to-switch/reopen hint; it does not contain mouse buttons that cannot receive input. Choose, replace, and remove pins in Settings. The production surface never draws a synthetic wallpaper, Dock, application, browser tab, or screenshot. Synthetic review data appears only in explicitly requested, isolated fixture mode.

## Brand identity

The approved Radial Context identity lives in [Brand](Brand/README.md): four
rounded radial segments and a central core, with equal gaps and controlled
cyan/blue/violet gradients. `WheelBrand` owns the small palette, exact tagline
“Move through your Mac context instantly.”, and bundled image loading.
`WheelBrandMark` reuses the vector PDFs for size and Light/Dark variants;
the monochrome status image is an 18 pt AppKit template. The real app icon is
a separately rendered, optically corrected iconset compiled into `Wheel.icns`.

Settings uses a compact identity header; About shows the actual app icon,
version/build and repository link. A 24 pt mark accompanies the overlay hub
title. Selection retains its outline, shape and check marker with a restrained
brand blue wash. Existing motion timing, accessibility behavior and system
control colors stay authoritative. Branding never creates a synthetic desktop
or app preview. See [brand QA](docs/BRAND_QA.md) for the evidence and physical
checks.

## Tokens and hierarchy

Use `WheelVisualTokens` and `WheelGlassSurface` as the shared semantic layer. Use system San Francisco typography and native controls; no bundled fonts.

| Token | Values / intent |
| --- | --- |
| Typography | Large title for page identity, title2 for sections, body/callout for controls, caption for state and hints; hub 25 pt medium with a 24 pt brand mark; app labels 11–12 pt medium/semibold |
| Spacing | 4, 6, 8, 12, 16, 20, 24, 32 pt |
| Radii | 8 tiny controls; 12 compact controls; 16 contextual groups; 20 cards; 24 detail panel; 28 major rectangular surfaces; circular overlay/hub |
| Surfaces | `overlay`, `hub`, `context`, `navigation`, `popover`, `control`, `selected`, `panel`; glass is for transient/navigation surfaces, solid semantic backgrounds for settings content |
| Border | Optical hairline 0.75–1 pt; selected 1.5 pt; increased contrast / differentiation 2–2.5 pt; use semantic separators for settings |
| Shadow | One shell shadow, approximately 18 pt / 8 pt vertical offset; detail 12 pt / 6 pt; smaller controls 4 pt / 2 pt; never stack broad blurred shadows per sector |
| Accent | Restrained desaturated cool blue for selected optical rim, low-opacity tint; system accent for native control focus |
| Selection | Brighter outline and fill, check marker, selected text weight; 1.045 scale and 4 pt outward displacement; other items retain at least 0.72 opacity after release |
| Hover | Gesture hover uses the same selection structure; native controls retain system hover/focus behavior |
| Pressed | Native buttons or shared glass button style with a short opacity/contrast response |
| Disabled | Native disabled control treatment, readable explanatory text; never hide a disabled control's purpose |
| Unavailable | `slash.circle` marker, explicit “Unavailable” text, no release-to-open promise; persistent pin remains present |
| Terminated application | `arrow.clockwise` marker, “Recently closed” / “Reopen” text; real existing relaunch path |
| Pinned application | Small `pin.fill` marker plus “Pinned” text in the detail surface and Settings; fixed sector assignment |
| Error | `exclamationmark.octagon` plus explicit error text and a real retry/permission recovery action |
| Success | `checkmark.circle` plus “Ready” / “Running” text; color is supplementary |
| Warning | `exclamationmark.triangle` plus explicit attention/experimental text |

White/silver and dark optical shading are permitted only for physically motivated border illumination and shadows. Foreground text, content surfaces, secondary labels, and separators use semantic system colors. Optical colors and opacity live in the theme, not individual screens.

## Glass compatibility

No external UI dependency. The Wheel-owned generic `WheelGlassSurface` chooses by role, appearance, accessibility, compiler/API availability:

- With Swift 6.2+ / a macOS 26 SDK, use `glassEffect(.regular, in:)` behind runtime `#available(macOS 26, *)`. It is a visual surface, not an interactive glass control on the click-through HUD.
- On macOS 14–25 (and older supported compilers), use SwiftUI native thin/regular material, a semantic contrast wash, an optical edge gradient, and one restrained shadow. No shaders, screenshots, networking, continuous animations, or third-party fallback package.
- Reduce Transparency and Increase Contrast select an opaque semantic surface with stronger outlines, bypassing both glass paths. Light and dark appearance adjust the optical border/shadow response while retaining semantic text colors.

Keep material decisions inside this abstraction. Sector segmentation uses lightweight static vector fills and strokes on the shared shell, not a separate blur per application. The hub uses standard regular material even on macOS 26, avoiding nested native glass inside the shell. The detail surface uses stronger text-bearing glass/material. Native macOS window/sidebar/popover chrome remains native. The opt-in `WHEEL_FORCE_MATERIAL` compiler flag allows fallback compilation and fixture review on a newer host; it does not replace testing on macOS 14.

## Motion and accessibility

Entrance: 160 ms opacity and 0.98-to-1 settling scale. Selection: 110 ms ease-out; no bounce, looping gradients, shimmer, expensive blur animation, or long spring. Dismissal retains the existing generation-guarded lifecycle.

Reduce Motion removes spatial translation/scale and uses immediate contrast/outline changes. Differentiate Without Color strengthens the outline and adds a selected check marker; ordinary selection already uses shape, weight, and outline as well as tint. Increase Contrast prevents low-contrast glass text; Reduce Transparency removes translucency. Decorative segmentation is hidden from accessibility. Application labels expose name, run state, pinned state, and selected state. Read-only gesture guidance is not represented as an accessible button.

The offscreen review renderer uses an additive `WheelAccessibilityReview` environment to enable these fallbacks without modifying get-only system environment values or global macOS preferences. Real system preferences always win. A check marker indicates a viable selected target; unavailable targets retain their slash marker, stronger outline, and explicit unavailable text.

## Settings and menu bar

Settings use `NavigationSplitView`, native grouped Forms, Toggle/Picker/Stepper/Button/LabeledContent, and eight sections: General, Wheel Layout, Applications, History, Appearance, Permissions, Advanced, About. Everyday screens lead with current behavior, layout, and pins. Raw signal counters, DOWN/UP state, recognized gestures, recovery counters, calibration, fixture information, and capability diagnostics belong to Advanced. Startup status does not imply launch-at-login support.

The compact menu shows status, current trigger, pause/resume/enable, permission attention when needed, recent real application if available, Open Settings, and Quit. No readiness score, metric cards, long dashboard, or nested glass cards.

Appearance follows the system and accessibility settings; no custom appearance preferences are required for this slice. Input Monitoring alone is required for current global gesture input. Accessibility and Screen Recording are not required for this application-only build.

## Research basis

External sources inform principles; approved repository visuals take precedence over branding:

- [Apple materials](https://developer.apple.com/design/human-interface-guidelines/materials), [macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos), [motion](https://developer.apple.com/design/human-interface-guidelines/motion): semantic native materials, functional glass, legible regular material, platform hierarchy, accessibility.
- [VoltAgent design references](https://github.com/VoltAgent/awesome-design-md): Apple clarity; Linear quiet hierarchy; Raycast compact keyboard utility; Superhuman speed/selection; Vercel spacing discipline. Typography and marketing decoration are not copied.
- [Radix](https://github.com/radix-ui/primitives), [MUI](https://github.com/mui/material-ui), [Ant Design](https://github.com/ant-design/ant-design): predictable state composition, keyboard behavior, semantic hierarchy, explicit disabled/error states; no dependencies or branded controls.
- [metneo/LiquidGlass](https://github.com/metneo/LiquidGlass): confirms a small material/highlight/border fallback is sufficient; Wheel owns its compatibility layer.

See [manual and fixture QA](docs/LIQUID_GLASS_QA.md) for review coverage and physical checks. Automated builds do not establish focus, full-screen, Input Monitoring, multi-display, or real wallpaper legibility evidence.
