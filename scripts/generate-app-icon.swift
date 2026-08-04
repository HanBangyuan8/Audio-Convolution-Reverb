#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let output = resources.appendingPathComponent("AppIcon.icns")
let readmePreview = resources.appendingPathComponent("AppIcon.png")
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

func writeIcon(size: Int, name: String) throws {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "AppIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to allocate bitmap \(name)"])
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))

    let iconMargin = CGFloat(size) * (96.0 / 1024.0)
    let corner = CGFloat(size) * 0.19
    let bodyRect = rect.insetBy(dx: iconMargin, dy: iconMargin)
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: corner, yRadius: corner)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.05, green: 0.13, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.46, blue: 0.58, alpha: 1),
        NSColor(calibratedRed: 0.93, green: 0.35, blue: 0.18, alpha: 1)
    ])?.draw(in: body, angle: 135)

    NSColor.white.withAlphaComponent(0.20).setStroke()
    body.lineWidth = max(1, CGFloat(size) * 0.012)
    body.stroke()

    let waveRect = bodyRect.insetBy(dx: CGFloat(size) * 0.18, dy: CGFloat(size) * 0.20)
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

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AppIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to render icon \(name)"])
    }
    try png.write(to: iconset.appendingPathComponent(name))
}

for variant in variants {
    try writeIcon(size: variant.0, name: variant.1)
}

try? fileManager.removeItem(at: output)
try? fileManager.removeItem(at: readmePreview)
try fileManager.copyItem(at: iconset.appendingPathComponent("icon_512x512@2x.png"), to: readmePreview)

let icnsChunks: [(String, String)] = [
    ("icp4", "icon_16x16.png"),
    ("ic11", "icon_16x16@2x.png"),
    ("icp5", "icon_32x32.png"),
    ("ic12", "icon_32x32@2x.png"),
    ("ic07", "icon_128x128.png"),
    ("ic13", "icon_128x128@2x.png"),
    ("ic08", "icon_256x256.png"),
    ("ic14", "icon_256x256@2x.png"),
    ("ic09", "icon_512x512.png"),
    ("ic10", "icon_512x512@2x.png")
]

func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndian = value.bigEndian
    withUnsafeBytes(of: &bigEndian) { data.append(contentsOf: $0) }
}

var chunks = Data()
for (type, fileName) in icnsChunks {
    let png = try Data(contentsOf: iconset.appendingPathComponent(fileName))
    chunks.append(type.data(using: .ascii)!)
    appendBigEndian(UInt32(png.count + 8), to: &chunks)
    chunks.append(png)
}

var icns = Data("icns".utf8)
appendBigEndian(UInt32(chunks.count + 8), to: &icns)
icns.append(chunks)
try icns.write(to: output, options: .atomic)

print(output.path)
