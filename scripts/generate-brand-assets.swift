#!/usr/bin/env swift
import AppKit
import CoreGraphics
import CoreText
import CryptoKit
import Foundation

// Wheel's authored vector geometry. This script is the source for SVG, PDF and
// each raster size; no icon is resized from another raster and no screenshot is used.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let brand = root.appendingPathComponent("Brand")
let resources = root.appendingPathComponent("Sources/WheelApp/Resources")
let iconset = root.appendingPathComponent("packaging/Wheel.iconset")
let previews = brand.appendingPathComponent("Previews")
for directory in [brand, resources, iconset, previews] {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
}

struct Point {
    var x: CGFloat
    var y: CGFloat
    var cg: CGPoint { CGPoint(x: x, y: y) }
}
func point(_ radius: CGFloat, _ angle: CGFloat, center: Point = Point(x: 50, y: 50)) -> Point {
    Point(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
}
func f(_ value: CGFloat) -> String { String(format: "%.5f", Double(value)) }

struct Geometry {
    let outer: CGFloat = 48
    let inner: CGFloat
    let core: CGFloat
    let gap: CGFloat
    let corner: CGFloat
    static let master = Geometry(inner: 26.2, core: 13.4, gap: 8, corner: 7)
    static func optical(_ pixels: Int) -> Geometry {
        if pixels <= 16 { return Geometry(inner: 25.6, core: 14.7, gap: 12, corner: 5.8) }
        if pixels <= 32 { return Geometry(inner: 26.2, core: 13.9, gap: 9, corner: 6.6) }
        return .master
    }
}

// Circular fillets are tangent both to the ring and to the radial edge. Unlike
// a stroked arc, these paths preserve equal inner/outer gaps and broad rounded caps.
struct Sector {
    var path = CGMutablePath()
    var svg = ""
    mutating func move(_ p: Point) {
        path.move(to: p.cg)
        svg += "M \(f(p.x)) \(f(p.y)) "
    }
    mutating func line(_ p: Point) {
        path.addLine(to: p.cg)
        svg += "L \(f(p.x)) \(f(p.y)) "
    }
    mutating func arc(_ center: Point, _ radius: CGFloat, _ start: CGFloat, _ end: CGFloat) {
        // Export identical cubic Bézier approximations in PDF, PNG and SVG.
        let steps = max(1, Int(ceil(abs(end - start) / (.pi / 2))))
        let delta = (end - start) / CGFloat(steps)
        for step in 0..<steps {
            let a = start + CGFloat(step) * delta
            let b = a + delta
            let k = 4 / 3 * tan(delta / 4)
            let p0 = point(radius, a, center: center)
            let p3 = point(radius, b, center: center)
            let p1 = Point(x: p0.x - k * radius * sin(a), y: p0.y + k * radius * cos(a))
            let p2 = Point(x: p3.x + k * radius * sin(b), y: p3.y - k * radius * cos(b))
            path.addCurve(to: p3.cg, control1: p1.cg, control2: p2.cg)
            svg += "C \(f(p1.x)) \(f(p1.y)) \(f(p2.x)) \(f(p2.y)) \(f(p3.x)) \(f(p3.y)) "
        }
    }
    mutating func close() { path.closeSubpath(); svg += "Z" }
}
func sector(_ index: Int, _ g: Geometry) -> Sector {
    let start = (CGFloat(index) * 90 + g.gap) * .pi / 180
    let end = (CGFloat(index + 1) * 90 - g.gap) * .pi / 180
    let ro = g.outer - g.corner
    let ri = g.inner + g.corner
    let bo = asin(g.corner / ro)
    let bi = asin(g.corner / ri)
    let outerRay = sqrt(ro * ro - g.corner * g.corner)
    let innerRay = sqrt(ri * ri - g.corner * g.corner)
    var s = Sector()
    s.move(point(g.outer, start + bo))
    s.arc(Point(x: 50, y: 50), g.outer, start + bo, end - bo)
    s.arc(point(ro, end - bo), g.corner, end - bo, end + .pi / 2)
    s.line(point(innerRay, end))
    s.arc(point(ri, end - bi), g.corner, end + .pi / 2, end - bi + .pi)
    s.arc(Point(x: 50, y: 50), g.inner, end - bi, start + bi)
    s.arc(point(ri, start + bi), g.corner, start + bi + .pi, start + 3 * .pi / 2)
    s.line(point(outerRay, start))
    s.arc(point(ro, start + bo), g.corner, start - .pi / 2, start + bo)
    s.close()
    return s
}

func color(_ hex: String, alpha: CGFloat = 1) -> CGColor {
    let value = UInt32(hex, radix: 16)!
    return CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [
        CGFloat((value >> 16) & 255) / 255, CGFloat((value >> 8) & 255) / 255,
        CGFloat(value & 255) / 255, alpha
    ])!
}
let segmentColors = [
    ["BE64EE", "8947EC", "5754ED"], // lower right: restrained purple / violet
    ["54E8F0", "2B9DEF", "4564EF"], // lower left: cyan / blue
    ["54EAF4", "2CA3F8", "347AF1"], // upper left: cyan / electric blue
    ["66E5F5", "2B93FF", "774DEF"]  // upper right: blue / violet
]
let lightSegmentColors = [
    ["A949E1", "7B3AD9", "4C48D9"],
    ["13B7C8", "167FDB", "3556D8"],
    ["13C4D3", "168FE2", "2865D9"],
    ["20BDD8", "217BE9", "693ACD"]
]
let coreColors = ["8CEAF8", "39AEF9", "454BEE"]
let lightCoreColors = ["39BFD7", "238DDF", "403FD2"]

func gradient(_ context: CGContext, _ colors: [String], _ start: CGPoint, _ end: CGPoint) {
    let values = colors.map { color($0) }
    let stops = values.indices.map { CGFloat($0) / CGFloat(values.count - 1) }
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: values as CFArray, locations: stops)!
    context.drawLinearGradient(g, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
func drawMark(_ context: CGContext, geometry g: Geometry = .master, light: Bool = false, monochrome: String? = nil) {
    for index in 0..<4 {
        context.saveGState()
        context.addPath(sector(index, g).path)
        if let monochrome {
            context.setFillColor(color(monochrome)); context.fillPath()
        } else {
            context.clip()
            let starts = [CGPoint(x: 75, y: 54), CGPoint(x: 6, y: 56), CGPoint(x: 8, y: 44), CGPoint(x: 58, y: 6)]
            let ends = [CGPoint(x: 51, y: 96), CGPoint(x: 45, y: 95), CGPoint(x: 46, y: 4), CGPoint(x: 94, y: 48)]
            gradient(context, (light ? lightSegmentColors : segmentColors)[index], starts[index], ends[index])
        }
        context.restoreGState()
    }
    context.saveGState()
    context.addEllipse(in: CGRect(x: 50 - g.core, y: 50 - g.core, width: g.core * 2, height: g.core * 2))
    if let monochrome {
        context.setFillColor(color(monochrome)); context.fillPath()
    } else {
        context.clip()
        gradient(context, light ? lightCoreColors : coreColors, CGPoint(x: 41, y: 37), CGPoint(x: 58, y: 64))
    }
    context.restoreGState()
}
func drawIcon(_ context: CGContext, pixels: Int) {
    let container = CGPath(roundedRect: CGRect(x: 6, y: 6, width: 88, height: 88), cornerWidth: 20, cornerHeight: 20, transform: nil)
    context.saveGState()
    if pixels >= 64 { context.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 2, color: color("020713", alpha: 0.24)) }
    context.addPath(container); context.setFillColor(color("0B1428")); context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(container); context.clip()
    gradient(context, ["263E66", "101F39", "090F20"], CGPoint(x: 32, y: 6), CGPoint(x: 67, y: 96))
    context.restoreGState()
    if pixels >= 32 {
        context.saveGState()
        context.addPath(container); context.setStrokeColor(color("6695EF", alpha: 0.34)); context.setLineWidth(0.4); context.strokePath()
        context.restoreGState()
    }
    context.saveGState()
    context.translateBy(x: 50, y: 50)
    context.scaleBy(x: 0.71, y: 0.71)
    context.translateBy(x: -50, y: -50)
    if pixels >= 64 {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 1.6), blur: 2.2, color: color("02040F", alpha: 0.45))
        drawMark(context, geometry: .optical(pixels), monochrome: "162846")
        context.restoreGState()
    }
    drawMark(context, geometry: .optical(pixels))
    context.restoreGState()
}

func png(width: Int, height: Int, draw: (CGContext) -> Void) throws -> Data {
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
    draw(context)
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    guard let data = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
    return data
}
func iconPNG(_ pixels: Int) throws -> Data {
    try png(width: pixels, height: pixels) { context in
        context.scaleBy(x: CGFloat(pixels) / 100, y: CGFloat(pixels) / 100)
        drawIcon(context, pixels: pixels)
    }
}
func pdf(_ name: String, size: CGFloat = 100, draw: (CGContext) -> Void) throws {
    let data = NSMutableData()
    let consumer = CGDataConsumer(data: data as CFMutableData)!
    var bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let context = CGContext(consumer: consumer, mediaBox: &bounds, nil)!
    context.beginPDFPage(nil)
    context.translateBy(x: 0, y: size); context.scaleBy(x: size / 100, y: -size / 100)
    draw(context)
    context.endPDFPage(); context.closePDF()
    // Quartz writes current dates and an ID into each PDF. Replace only equal-
    // length metadata values to make regeneration stable without changing xrefs.
    var bytes = Array(data as Data)
    for prefix in ["/CreationDate (D:", "/ModDate (D:"] {
        let marker = Array(prefix.utf8)
        if let offset = bytes.indices.first(where: { index in
            index + marker.count <= bytes.count && Array(bytes[index..<(index + marker.count)]) == marker
        }) {
            bytes.replaceSubrange((offset + marker.count)..<(offset + marker.count + 14), with: "20260101000000".utf8)
        }
    }
    let idMarker = Array("/ID [ <".utf8)
    if let offset = bytes.indices.first(where: { index in
        index + idMarker.count <= bytes.count && Array(bytes[index..<(index + idMarker.count)]) == idMarker
    }) {
        let first = offset + idMarker.count
        let secondMarker = Array("\n<".utf8)
        let remainder = Array(bytes[(first + 32)...])
        if let secondOffset = remainder.indices.first(where: { index in
            index + secondMarker.count <= remainder.count && Array(remainder[index..<(index + secondMarker.count)]) == secondMarker
        }) {
            let second = first + 32 + secondOffset + secondMarker.count
            let zeroID = String(repeating: "0", count: 32)
            bytes.replaceSubrange(first..<(first + 32), with: zeroID.utf8)
            bytes.replaceSubrange(second..<(second + 32), with: zeroID.utf8)
            let identifier = SHA256.hash(data: Data(bytes)).prefix(16).map { String(format: "%02x", $0) }.joined()
            bytes.replaceSubrange(first..<(first + 32), with: identifier.utf8)
            bytes.replaceSubrange(second..<(second + 32), with: identifier.utf8)
        }
    }
    try Data(bytes).write(to: resources.appendingPathComponent(name))
}

func svg(_ monochrome: String? = nil, light: Bool = false, geometry g: Geometry = .master) -> String {
    var defs = ""
    let starts = [(75,54),(6,56),(8,44),(58,6)]
    let ends = [(51,96),(45,95),(46,4),(94,48)]
    if monochrome == nil {
        for index in 0..<4 {
            let colors = (light ? lightSegmentColors : segmentColors)[index]
            let stops = colors.enumerated().map { "<stop offset=\"\($0.offset * 50)%\" stop-color=\"#\($0.element)\"/>" }.joined()
            defs += "<linearGradient id=\"segment\(index)\" gradientUnits=\"userSpaceOnUse\" x1=\"\(starts[index].0)\" y1=\"\(starts[index].1)\" x2=\"\(ends[index].0)\" y2=\"\(ends[index].1)\">\(stops)</linearGradient>\n"
        }
        let stops = (light ? lightCoreColors : coreColors).enumerated().map { "<stop offset=\"\($0.offset * 50)%\" stop-color=\"#\($0.element)\"/>" }.joined()
        defs += "<linearGradient id=\"core\" gradientUnits=\"userSpaceOnUse\" x1=\"41\" y1=\"37\" x2=\"58\" y2=\"64\">\(stops)</linearGradient>"
    }
    let paths = (0..<4).map { index in
        "<path d=\"\(sector(index, g).svg)\" fill=\"\(monochrome.map { "#\($0)" } ?? "url(#segment\(index))")\"/>"
    }.joined(separator: "\n")
    let fill = monochrome.map { "#\($0)" } ?? "url(#core)"
    return """
    <svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100" role="img" aria-labelledby="title">
    <title id="title">Wheel — Radial Context</title>
    <defs>\(defs)</defs>
    \(paths)
    <circle cx="50" cy="50" r="\(f(g.core))" fill="\(fill)"/>
    </svg>
    """
}
func write(_ name: String, _ content: String) throws {
    try content.write(to: brand.appendingPathComponent(name), atomically: true, encoding: .utf8)
}
try write("WheelSymbol.svg", svg())
try write("WheelSymbolDark.svg", svg())
try write("WheelSymbolLight.svg", svg(light: true))
try write("WheelSymbolMonochromeBlack.svg", svg("000000"))
try write("WheelSymbolMonochromeWhite.svg", svg("FFFFFF"))
try write("WheelMenuBarTemplate.svg", svg("000000", geometry: .optical(16)).replacingOccurrences(of: "width=\"100\" height=\"100\"", with: "width=\"18\" height=\"18\""))

// Wordmark glyphs are outlines, so the production master does not need a font.
let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 76, nil)
let line = CTLineCreateWithAttributedString(NSAttributedString(string: "Wheel", attributes: [.font: font]))
let word = CGMutablePath()
for run in CTLineGetGlyphRuns(line) as! [CTRun] {
    let count = CTRunGetGlyphCount(run)
    var glyphs = [CGGlyph](repeating: 0, count: count)
    var positions = [CGPoint](repeating: .zero, count: count)
    CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
    CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
    for index in 0..<count {
        if let path = CTFontCreatePathForGlyph(font, glyphs[index], nil) {
            let t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 122 + positions[index].x, ty: 77)
            word.addPath(path, transform: t)
        }
    }
}
func pathData(_ path: CGPath) -> String {
    var result = ""
    path.applyWithBlock { element in
        let e = element.pointee
        let p = e.points
        switch e.type {
        case .moveToPoint: result += "M \(f(p[0].x)) \(f(p[0].y)) "
        case .addLineToPoint: result += "L \(f(p[0].x)) \(f(p[0].y)) "
        case .addQuadCurveToPoint: result += "Q \(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y)) "
        case .addCurveToPoint: result += "C \(f(p[0].x)) \(f(p[0].y)) \(f(p[1].x)) \(f(p[1].y)) \(f(p[2].x)) \(f(p[2].y)) "
        case .closeSubpath: result += "Z "
        @unknown default: break
        }
    }
    return result
}
let wordmark = svg().replacingOccurrences(of: "width=\"100\" height=\"100\" viewBox=\"0 0 100 100\"", with: "width=\"380\" height=\"100\" viewBox=\"0 0 380 100\"")
    .replacingOccurrences(of: "</svg>", with: "<path d=\"\(pathData(word))\" fill=\"#F4F7FC\"/></svg>")
try write("WheelWordmark.svg", wordmark)
try write("WheelWordmarkLight.svg", wordmark.replacingOccurrences(of: "#F4F7FC", with: "#111827"))

let symbolBody = svg().components(separatedBy: "\n").dropFirst().dropLast().joined(separator: "\n")
let appIconSVG = """
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 100 100" role="img" aria-labelledby="appTitle">
<title id="appTitle">Wheel macOS app icon</title>
<defs>
<linearGradient id="container" x1="32" y1="6" x2="67" y2="96" gradientUnits="userSpaceOnUse"><stop stop-color="#263E66"/><stop offset="50%" stop-color="#101F39"/><stop offset="100%" stop-color="#090F20"/></linearGradient>
<filter id="containerShadow" x="-10%" y="-10%" width="120%" height="125%"><feDropShadow dx="0" dy="1.5" stdDeviation="1" flood-color="#020713" flood-opacity=".24"/></filter>
<filter id="symbolShadow" x="-10%" y="-10%" width="120%" height="125%"><feDropShadow dx="0" dy="1.6" stdDeviation="1.1" flood-color="#02040F" flood-opacity=".45"/></filter>
</defs>
<rect x="6" y="6" width="88" height="88" rx="20" fill="url(#container)" stroke="#6695EF" stroke-opacity=".34" stroke-width=".4" filter="url(#containerShadow)"/>
<g transform="translate(50 50) scale(.71) translate(-50 -50)" filter="url(#symbolShadow)">
\(symbolBody)
</g>
</svg>
"""
try write("WheelAppIcon.svg", appIconSVG)

try pdf("WheelSymbol.pdf") { drawMark($0) }
try pdf("WheelSymbolLight.pdf") { drawMark($0, light: true) }
try pdf("WheelSymbolMonochromeBlack.pdf") { drawMark($0, monochrome: "000000") }
try pdf("WheelSymbolMonochromeWhite.pdf") { drawMark($0, monochrome: "FFFFFF") }
try pdf("WheelMenuBarTemplate.pdf", size: 18) { drawMark($0, geometry: .optical(16), monochrome: "000000") }

let sizes = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in sizes { try iconPNG(size).write(to: iconset.appendingPathComponent(name)) }
let master = try iconPNG(1024)
try master.write(to: root.appendingPathComponent("packaging/Wheel-icon.png"))
try master.write(to: resources.appendingPathComponent("WheelAppIcon.png"))

func text(_ context: CGContext, _ value: String, at point: CGPoint, size: CGFloat, color hex: String = "E9EFF8") {
    context.saveGState()
    context.translateBy(x: point.x, y: point.y); context.scaleBy(x: 1, y: -1)
    context.textMatrix = .identity
    context.textPosition = .zero
    let string = NSAttributedString(string: value, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: .medium),
        .foregroundColor: NSColor(cgColor: color(hex))!
    ])
    CTLineDraw(CTLineCreateWithAttributedString(string), context)
    context.restoreGState()
}
let sheet = try png(width: 1100, height: 920) { context in
    context.setFillColor(color("0B1322")); context.fill(CGRect(x: 0, y: 0, width: 1100, height: 920))
    text(context, "Wheel · production asset review", at: CGPoint(x: 30, y: 43), size: 25)
    text(context, "Direct vector renders · actual pixel sizes · no desktop mockups", at: CGPoint(x: 30, y: 69), size: 14, color: "A8BAD2")
    for (i, size) in [16, 32, 64, 128, 512].enumerated() {
        let x: CGFloat = [34, 120, 220, 352, 556][i]
        context.saveGState(); context.translateBy(x: x, y: 112)
        context.scaleBy(x: CGFloat(size) / 100, y: CGFloat(size) / 100)
        drawIcon(context, pixels: size); context.restoreGState()
        text(context, "\(size) px", at: CGPoint(x: x, y: CGFloat(size) + 135), size: 14)
    }
    context.setFillColor(color("EFF2F7")); context.fill(CGRect(x: 0, y: 684, width: 1100, height: 236))
    text(context, "Light surface", at: CGPoint(x: 30, y: 715), size: 15, color: "26344C")
    text(context, "Menu bar template · 18 px", at: CGPoint(x: 200, y: 715), size: 15, color: "26344C")
    text(context, "Color mark · 96 px", at: CGPoint(x: 440, y: 715), size: 15, color: "26344C")
    context.saveGState(); context.translateBy(x: 40, y: 746); context.scaleBy(x: 1.28, y: 1.28); drawIcon(context, pixels: 128); context.restoreGState()
    context.saveGState(); context.translateBy(x: 220, y: 755); context.scaleBy(x: 0.18, y: 0.18); drawMark(context, geometry: .optical(16), monochrome: "111827"); context.restoreGState()
    context.saveGState(); context.translateBy(x: 470, y: 746); context.scaleBy(x: 0.96, y: 0.96); drawMark(context, light: true); context.restoreGState()
    for (size, x, magnification) in [(16, CGFloat(715), CGFloat(6)), (32, CGFloat(900), CGFloat(3))] {
        let data = try! iconPNG(size)
        let source = NSBitmapImageRep(data: data)!.cgImage!
        context.saveGState(); context.interpolationQuality = .none
        context.translateBy(x: x, y: 746 + CGFloat(size) * magnification); context.scaleBy(x: 1, y: -1)
        context.draw(source, in: CGRect(x: 0, y: 0, width: CGFloat(size) * magnification, height: CGFloat(size) * magnification))
        context.restoreGState()
        text(context, "\(size) px × \(Int(magnification))", at: CGPoint(x: x, y: 870), size: 14, color: "26344C")
    }
    text(context, "Dark surface", at: CGPoint(x: 32, y: 635), size: 15)
    context.saveGState(); context.translateBy(x: 230, y: 617); context.scaleBy(x: 0.18, y: 0.18); drawMark(context, geometry: .optical(16), monochrome: "FFFFFF"); context.restoreGState()
    text(context, "Menu template · 18 px", at: CGPoint(x: 265, y: 635), size: 14)
}
try sheet.write(to: previews.appendingPathComponent("WheelAssetReview.png"))
print("Generated Wheel SVG masters, vector runtime PDFs, 10 iconset images, 1024 px app icon and Brand/Previews/WheelAssetReview.png")
