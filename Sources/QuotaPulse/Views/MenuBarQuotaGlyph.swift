import AppKit
import SwiftUI

struct MenuBarQuotaGlyph: View {
    var body: some View {
        Image(nsImage: Self.templateImage)
            .resizable()
            .renderingMode(.template)
            .interpolation(.high)
            .frame(width: 16, height: 16)
            .accessibilityHidden(true)
    }

    private static let templateImage: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let center = NSPoint(x: rect.midX, y: rect.midY)
            for angles in [(36.0, 130.0), (146.0, 240.0), (256.0, 340.0)] {
                let segment = NSBezierPath()
                segment.appendArc(
                    withCenter: center,
                    radius: 5.7,
                    startAngle: angles.0,
                    endAngle: angles.1
                )
                segment.lineWidth = 2.55
                segment.lineCapStyle = .round
                segment.stroke()
            }

            NSBezierPath(ovalIn: NSRect(x: 13.9, y: 7.6, width: 2.8, height: 2.8)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
