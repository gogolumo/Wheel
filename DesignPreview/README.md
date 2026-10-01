# Wheel Design Preview

This directory is a **standalone visual prototype**. It does not modify or import Wheel production UI and it does not request macOS permissions.

## Open it

```bash
open DesignPreview/index.html
```

The preview is self-contained: no package install, build step, network request, analytics, or external font is required.

## Controls

- `A`, `B`, `C`: switch between the three visual directions.
- `1`–`5`: switch between Overlay, Settings, Applications, Permissions, and Menu Bar.
- Left / Right arrow: move the selected radial context.
- Click or hover a radial context to inspect the selected state.
- Use the top-right half-circle control to inspect light and dark appearance.

## What this preview is proving

1. Wheel can feel spatial without becoming a launcher grid or gaming HUD.
2. Product-facing UI can hide engineering diagnostics while preserving them under Advanced.
3. Pinned, running, and recently-closed contexts can remain distinguishable with subtle, non-notification styling.
4. Permissions can be progressive: Input Monitoring for the core gesture, Accessibility for deeper restoration where needed, and Screen Recording only if rich local previews actually require it.
5. The overlay can stay readable without using blur on every individual surface.

## Mock data boundary

The app names, window titles, preview labels, permission states, and recent-context content in this prototype are **synthetic design data**. Nothing in this directory captures live windows or claims that a fake screenshot is a real live preview.

## Production gate

Do not copy this directory into production views until the design direction is approved and the product-semantic conflict between current `main` (strict Back/Forward MVP) and the radial application branches is resolved explicitly.
