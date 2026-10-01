# Wheel UI audit and design direction

## Scope

This research is based on:

- current `main` and `PROJECT_RULES.md`;
- the current app-shell / context-history / installable-app / pinned-app branch stack;
- `Sources/WheelApp/WheelAppViews.swift`;
- `Sources/WheelApp/WheelGestureOverlayView.swift`;
- `WheelSettings`, `WheelPinnedSlotStore`, `WheelContextEligibilityPolicy`;
- Raycast, Linear, Apple, Superhuman and Vercel `DESIGN.md` references from `VoltAgent/awesome-design-md`;
- Apple Human Interface Guidelines for macOS, materials, settings, popovers, motion and accessibility.

## Critical product conflict

`main` still defines Wheel primarily as browser-style Back / Forward for the whole Mac. Its product contract fixes LEFT as previous, RIGHT as next, and explicitly rejects turning the product into a generic radial launcher.

The active UI branch stack already contains a multi-sector radial application selector, configurable direction count, recently closed applications, and pinned fixed sectors.

That is not a cosmetic difference. Before production redesign, the project needs an explicit product/ADR decision describing how the radial context ring relates to the canonical Back / Forward history model. This preview does not silently rewrite that contract.

## Current UI audit

### Strong foundations

- Native SwiftUI/AppKit application shell and global overlay panel.
- Real application history and relaunch behavior already exist in the branch stack.
- Pinned sectors are modeled separately from presentation and persist by stable identity.
- Context eligibility is positive by default: only regular user-facing applications enter history; known authentication and background surfaces are excluded.
- The overlay already respects Reduced Motion, exposes accessibility labels, uses real application icons and distinguishes terminated applications.
- Short 120 ms selection transitions are directionally correct for a frequently used utility.

### Prototype signals to remove from everyday product UI

- MVP readiness score and build-state language.
- Matching trigger signal counts, raw DOWN/UP edges and event-tap recovery counters.
- Large Overview metric cards for service / trigger / recognized count.
- Visible calibration controls as a first-class settings section.
- Repeated indigo-blue gradients as generic visual decoration.

These are useful engineering diagnostics, but they make Wheel look like an internal debug console. They should move to Advanced / Diagnostics.

### Overlay issues

- The current 492 pt translucent circle is recognizably a radial app launcher, while Wheel's strongest product idea is context history.
- Context items are mostly app icon + app name, so the UI does not yet explain *which context* is being restored.
- The center hub carries trigger, status text and counts instead of acting as a quiet spatial anchor for the current context.
- Selection is communicated mainly by accent color, 3 px stroke and 1.08 scale. It needs stronger non-color hierarchy: depth, label expansion, border weight and motion.
- `accessibilityDifferentiateWithoutColor` is read but the current presentation shown in the branch does not visibly use it.
- A single `ultraThinMaterial` background can become too transparent on visually busy windows. Material thickness must follow legibility, not style.

### Settings issues

- Default `GroupBox`, large titles and a dashboard-like Overview look like a SwiftUI sample rather than a finished macOS utility.
- The current menu-bar popover is too tall and includes build readiness; a transient popover should focus on status, trigger, pause/resume, settings and quit.
- Settings structure should separate normal user choices from debugging/calibration.

## Reference extraction

The `awesome-design-md` files are useful **visual analyses**, not authoritative in-product design systems. Several describe marketing sites. They should be treated as vocabulary, not copied literally.

### Raycast

Use: dense keyboard-tool rhythm, dark surface ladder, keycap language, hairline borders, quick scan hierarchy.

Avoid: carrying marketing red gradients or web typography directly into native macOS.

### Linear

Use: disciplined near-black surface hierarchy, one restrained accent, tight borders and low visual noise.

Avoid: turning Wheel into a generic dark SaaS panel.

### Apple

Use: system typography, semantic materials, native control behavior, accessibility, reduced motion, platform-consistent settings structure.

Avoid: copying consumer-marketing scale or excessive empty white space into a compact utility.

### Superhuman

Use: speed, keyboard-first density and strong hierarchy with few simultaneous actions.

Avoid: importing its marketing/editorial color blocks into Wheel.

### Vercel

Use: typography discipline, monochrome clarity, technical captions and spacing precision.

Avoid: web-first mesh gradients and pill-heavy controls.

## Three directions

### A — Spatial Glass — recommended

- One semantic material layer for the overlay, not glass on every object.
- Crisp context cards over the material.
- System accent only for selection/focus.
- Rounded but not bubbly: 8 / 12 / 18 / 28 pt radii by role.
- SF Pro / system typography.
- 150–180 ms overlay entrance, 110–140 ms selection response, Reduced Motion fallback.
- Best fit for a native premium utility because it preserves desktop context without turning into decorative glassmorphism.

### B — Precision Dark

- Near-black opaque surfaces and hairline borders.
- Minimal blur and minimal shadow.
- Slightly tighter radii and spacing.
- Best raw legibility and cheapest rendering profile.
- Risk: can feel too much like another developer tool and lose Wheel's spatial identity.

### C — Spatial Canvas

- The outer ring visually recedes; context cards float around a spatial anchor.
- Selected context gets the strongest depth and expanded information.
- More distinctive and expressive.
- Risk: easiest direction to over-design; must avoid gaming/HUD motion and theatrical depth.

## Recommended Wheel language

Use **Spatial Glass** as the base, with Linear's discipline and Raycast's keyboard density.

Principles:

1. Context, not app, is the primary visual object.
2. Material is structural. Accent color is semantic.
3. Selection must remain obvious without color.
4. Product UI hides engineering diagnostics by default.
5. The menu bar is a compact control surface, not a dashboard.
6. Rich previews are optional and local; icons/titles remain a complete fallback.
7. Current Back / Forward invariants remain visible in product semantics until an ADR explicitly changes them.
