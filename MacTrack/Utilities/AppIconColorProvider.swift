import AppKit
import SwiftUI

enum AppIconColorProvider {
    private static let cache = NSCache<NSString, NSColor>()

    static func color(forBundleIdentifier bundleIdentifier: String) -> Color {
        guard !bundleIdentifier.isEmpty else {
            return Color.secondary.opacity(0.4)
        }
        let key = bundleIdentifier as NSString
        if let cached = cache.object(forKey: key) {
            return Color(nsColor: cached)
        }
        guard let icon = AppIconProvider.icon(forBundleIdentifier: bundleIdentifier),
              let sampled = sampleAccentColor(from: icon) else {
            return Color.secondary.opacity(0.4)
        }
        cache.setObject(sampled, forKey: key)
        return Color(nsColor: sampled)
    }

    private static func sampleAccentColor(from image: NSImage) -> NSColor? {
        let pixelSize = 32
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelSize,
            pixelsHigh: pixelSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(
            in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        NSGraphicsContext.restoreGraphicsState()

        guard let data = rep.bitmapData else { return nil }
        let bytesPerPixel = 4
        var rSum = 0.0
        var gSum = 0.0
        var bSum = 0.0
        var weightSum = 0.0

        for y in 0..<pixelSize {
            for x in 0..<pixelSize {
                let offset = (y * pixelSize + x) * bytesPerPixel
                let a = Double(data[offset + 3]) / 255
                guard a > 0.35 else { continue }

                let r = Double(data[offset]) / 255
                let g = Double(data[offset + 1]) / 255
                let b = Double(data[offset + 2]) / 255
                let brightness = (r + g + b) / 3
                guard brightness > 0.08, brightness < 0.94 else { continue }

                let maxC = max(r, g, b)
                let minC = min(r, g, b)
                let saturation = maxC > 0.001 ? (maxC - minC) / maxC : 0
                let weight = a * (0.25 + saturation * 0.75)
                guard weight > 0.05 else { continue }

                rSum += r * weight
                gSum += g * weight
                bSum += b * weight
                weightSum += weight
            }
        }

        guard weightSum > 0 else { return nil }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        let color = NSColor(
            red: rSum / weightSum,
            green: gSum / weightSum,
            blue: bSum / weightSum,
            alpha: 1
        )
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
        saturation = min(1, max(0.45, saturation * 1.15))
        brightness = min(0.82, max(0.42, brightness))
        return NSColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1)
    }
}
