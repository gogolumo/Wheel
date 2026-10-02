# Wheel brand assets

**Move through your Mac context instantly.**

These production assets recreate the approved **Radial Context** direction as
authored vector geometry. They contain no pixels cropped from the reference board.

| Master | Use |
| --- | --- |
| `WheelSymbol.svg` / `WheelSymbolDark.svg` | Primary color mark on dark surfaces |
| `WheelSymbolLight.svg` | Deeper cyan/blue treatment on light surfaces |
| `WheelSymbolMonochromeBlack.svg` | Black silhouette |
| `WheelSymbolMonochromeWhite.svg` | White silhouette |
| `WheelWordmark.svg` | Color symbol and outlined white Wheel lettering |
| `WheelWordmarkLight.svg` | Color symbol and outlined graphite Wheel lettering |
| `WheelAppIcon.svg` | macOS rounded-square app icon master |
| `WheelMenuBarTemplate.svg` | Optically corrected monochrome status-icon master |

The wordmark uses outlined Helvetica Neue Bold glyphs; it has no runtime font
dependency. The tagline remains selectable text in the app and README.

## Geometry and palette

The symbol uses a `100 × 100` coordinate system, center `(50, 50)`, outer radius
`48`, inner radius `26.2`, and core radius `13.4`. Four identical annular sectors
span `74°` each, separated by equal `16°` angular gaps. Each corner is a true
circular fillet with radius `7`, tangent to its radial edge and its inner or outer
circle. SVG and CoreGraphics share the same cubic Bézier paths.

| Token | Color |
| --- | --- |
| Primary navy | `#0B1428` |
| Secondary navy | `#172C52` |
| Cyan | `#4DE7F4` |
| Electric blue | `#258CFF` |
| Blue-violet | `#6350EE` |
| Subtle purple | `#B45BEF` |

Each segment has a controlled three-stop gradient; the core uses cyan through
blue to violet. The app icon adds a navy material gradient, a restrained rim and
short shadow. It has no neon bloom. Monochrome variants preserve the geometry.

## Apple resources

`Sources/WheelApp/Resources/` contains color and monochrome vector PDFs plus the
`1024 × 1024` true app-icon PNG. `WheelMenuBarTemplate.pdf` is an `18 × 18 pt`
black vector silhouette with optical correction. AppKit must set `isTemplate`
on the loaded status image; macOS then supplies the appropriate menu-bar color.

`packaging/Wheel.iconset/` contains all ten conventional macOS iconset files.
`packaging/Wheel-icon.png` is the full-size `1024 × 1024` app icon. The bundle
builder creates its ICNS from the committed iconset, preserving optical changes
at the small sizes.

Every PNG is drawn directly from the geometry at its final pixel size. The
`16 px` treatment increases the core radius to `14.7`, widens the angular gap
to `24°` and reduces fillets to `5.8`; `32 px` uses core radius `13.9`, `18°`
gaps and `6.6` fillets. The stronger core and gaps remain visible without
upscaling, sharpening or blurring a raster source.

## Regeneration and review

Run from the repository root on macOS:

```bash
swift -warnings-as-errors scripts/generate-brand-assets.swift
```

This native AppKit/CoreGraphics/CoreText generator has no external dependencies.
It writes SVG masters, vector PDFs, all icon rasters and
[`Previews/WheelAssetReview.png`](Previews/WheelAssetReview.png). PDF dates and
identifiers are normalized so rerunning on the same SDK produces stable assets.

The review sheet shows real generated assets at `16`, `32`, `64`, `128` and
`512 px`, the menu template on light/dark surfaces and separately labeled pixel
magnification of `16` and `32 px`. It is an asset contact sheet, not a screenshot
of Dock, Finder or the running app. Desktop and application integration checks
must be recorded separately.

[`Previews/WheelResolvedAppIcon.png`](Previews/WheelResolvedAppIcon.png) is the
512 px icon returned by native `NSWorkspace.icon(forFile:)` for a real installed
Wheel.app. macOS applies its icon presentation treatment. This is an actual
application-icon lookup, not a Finder window or Dock screenshot. See
[brand integration QA](../docs/BRAND_QA.md) for packaged UI evidence and limits.
