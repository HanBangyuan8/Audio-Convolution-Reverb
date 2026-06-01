#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let output = resources.appendingPathComponent("AppIcon.icns")
let fileManager = FileManager.default

try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

let artworkScale: CGFloat = 832.0 / 1024.0

func writeIcon(size: Int, name: String) throws {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let image = NSImage(size: rect.size)
    image.lockFocus()

    let artworkSize = CGFloat(size) * artworkScale
    let iconRect = NSRect(
        x: (CGFloat(size) - artworkSize) / 2,
        y: (CGFloat(size) - artworkSize) / 2,
        width: artworkSize,
        height: artworkSize
    )
    let outlineWidth = max(1, CGFloat(size) * 0.012)
    let backgroundRect = iconRect.insetBy(dx: outlineWidth / 2, dy: outlineWidth / 2)
    let background = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: backgroundRect.width * 0.22,
        yRadius: backgroundRect.height * 0.22
    )
    NSGradient(colors: [
        NSColor(calibratedRed: 0.05, green: 0.13, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.46, blue: 0.58, alpha: 1),
        NSColor(calibratedRed: 0.93, green: 0.35, blue: 0.18, alpha: 1)
    ])?.draw(in: background, angle: 135)

    NSColor.white.withAlphaComponent(0.22).setStroke()
    background.lineWidth = outlineWidth
    background.stroke()

    let waveRect = iconRect.insetBy(dx: iconRect.width * 0.20, dy: iconRect.height * 0.27)
    let centerY = waveRect.midY
    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: waveRect.minX, y: centerY))

    let segments = 5
    for segment in 0..<segments {
        let startX = waveRect.minX + waveRect.width * CGFloat(segment) / CGFloat(segments)
        let endX = waveRect.minX + waveRect.width * CGFloat(segment + 1) / CGFloat(segments)
        let midX = (startX + endX) / 2
        let direction: CGFloat = segment.isMultiple(of: 2) ? 1 : -1
        wave.curve(
            to: NSPoint(x: endX, y: centerY),
            controlPoint1: NSPoint(x: startX + (midX - startX) * 0.62, y: centerY + waveRect.height * 0.48 * direction),
            controlPoint2: NSPoint(x: midX + (endX - midX) * 0.38, y: centerY + waveRect.height * 0.48 * direction)
        )
    }

    NSColor.white.setStroke()
    wave.lineCapStyle = .round
    wave.lineJoinStyle = .round
    wave.lineWidth = max(2, CGFloat(size) * 0.052)
    wave.stroke()

    let echo = NSBezierPath()
    echo.move(to: NSPoint(x: waveRect.minX + waveRect.width * 0.08, y: centerY - waveRect.height * 0.34))
    echo.curve(
        to: NSPoint(x: waveRect.maxX - waveRect.width * 0.08, y: centerY - waveRect.height * 0.34),
        controlPoint1: NSPoint(x: waveRect.minX + waveRect.width * 0.34, y: centerY - waveRect.height * 0.62),
        controlPoint2: NSPoint(x: waveRect.maxX - waveRect.width * 0.34, y: centerY - waveRect.height * 0.06)
    )
    NSColor.white.withAlphaComponent(0.42).setStroke()
    echo.lineCapStyle = .round
    echo.lineWidth = max(1, CGFloat(size) * 0.026)
    echo.stroke()

    image.unlockFocus()

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "AppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to render icon \(name)"])
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

for variant in variants {
    try writeIcon(size: variant.0, name: variant.1)
}

try? fileManager.removeItem(at: output)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw NSError(domain: "AppIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

try? fileManager.removeItem(at: iconset)
print(output.path)
