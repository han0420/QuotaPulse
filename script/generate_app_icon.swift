#!/usr/bin/env swift

import AppKit
import Foundation

private let canvasSize = 1024
private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let sourceURL = root.appendingPathComponent("script/assets/QuotaPulse-AppIcon-Master.png")
private let resources = root.appendingPathComponent("Sources/QuotaPulse/Resources", isDirectory: true)
private let pngURL = resources.appendingPathComponent("AppIcon.png")
private let icnsURL = resources.appendingPathComponent("AppIcon.icns")

guard let sourceImage = NSImage(contentsOf: sourceURL) else {
    fatalError("Unable to load icon master at \(sourceURL.path)")
}

private func makeIcon(size: Int) -> NSBitmapImageRep {
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
    ), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create \(size)px bitmap")
    }

    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    graphics.imageInterpolation = .high
    sourceImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .copy,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

private func pngData(for bitmap: NSBitmapImageRep) -> Data {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode PNG")
    }
    return data
}

try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try pngData(for: makeIcon(size: canvasSize)).write(to: pngURL, options: .atomic)

let representations: [(type: String, size: Int)] = [
    ("icp4", 16),
    ("icp5", 32),
    ("icp6", 64),
    ("ic07", 128),
    ("ic08", 256),
    ("ic09", 512),
    ("ic10", 1024),
]

private func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var encoded = value.bigEndian
    withUnsafeBytes(of: &encoded) { bytes in
        data.append(contentsOf: bytes)
    }
}

let chunks = representations.map { representation -> Data in
    let imageData = pngData(for: makeIcon(size: representation.size))
    var chunk = Data(representation.type.utf8)
    appendBigEndian(UInt32(imageData.count + 8), to: &chunk)
    chunk.append(imageData)
    return chunk
}

var icnsData = Data("icns".utf8)
appendBigEndian(UInt32(chunks.reduce(8) { $0 + $1.count }), to: &icnsData)
for chunk in chunks {
    icnsData.append(chunk)
}
try icnsData.write(to: icnsURL, options: .atomic)

print("Generated \(pngURL.path) and \(icnsURL.path) from \(sourceURL.path)")
