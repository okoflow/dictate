// Run from the repository root: swift scripts/generate-icon.swift
// AppKit draws every standard and Retina size directly from the same geometry.
import AppKit

func drawIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw CocoaError(.fileWriteUnknown)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }
    context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
    let scale = CGFloat(size) / 1024
    context.cgContext.scaleBy(x: scale, y: scale)
    drawTile()
    drawMicrophone()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }
    return png
}

func drawTile() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864),
                            xRadius: 196, yRadius: 196)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    NSColor(calibratedRed: 0.27, green: 0.25, blue: 0.85, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()

    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.98, alpha: 1),
        ending: NSColor(calibratedRed: 0.40, green: 0.22, blue: 0.84, alpha: 1)
    )
    gradient?.draw(in: tile, angle: -60)
    NSColor.white.withAlphaComponent(0.18).setStroke()
    tile.lineWidth = 3
    tile.stroke()
}

/// A bold microphone silhouette stays legible at 16 px.
func drawMicrophone() {
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 410, y: 420, width: 204, height: 350),
                 xRadius: 102, yRadius: 102).fill()
    let stand = NSBezierPath()
    stand.move(to: NSPoint(x: 326, y: 535))
    stand.line(to: NSPoint(x: 326, y: 495))
    stand.curve(to: NSPoint(x: 512, y: 309),
                controlPoint1: NSPoint(x: 326, y: 392), controlPoint2: NSPoint(x: 409, y: 309))
    stand.curve(to: NSPoint(x: 698, y: 495),
                controlPoint1: NSPoint(x: 615, y: 309), controlPoint2: NSPoint(x: 698, y: 392))
    stand.line(to: NSPoint(x: 698, y: 535))
    stand.move(to: NSPoint(x: 512, y: 309))
    stand.line(to: NSPoint(x: 512, y: 235))
    stand.move(to: NSPoint(x: 422, y: 235))
    stand.line(to: NSPoint(x: 602, y: 235))
    stand.lineWidth = 56
    stand.lineCapStyle = .round
    stand.lineJoinStyle = .round
    NSColor.white.setStroke()
    stand.stroke()
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/Dictate.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let suffix = scale == 2 ? "@2x" : ""
        let png = try drawIcon(size: size * scale)
        try png.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
        if size == 512, scale == 2 {
            try png.write(to: root.appendingPathComponent("Packaging/Dictate.png"))
        }
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Packaging/Dictate.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(iconutil.terminationStatus) }
print("Generated Packaging/Dictate.icns and Packaging/Dictate.png")
