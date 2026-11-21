import AppKit

@MainActor
enum LCDMaterial {
    static let ink = color(0x333e2b)
    static let silkInk = color(0x303c28)
    static let inactiveInk = ink.withAlphaComponent(0.045)

    static func image(named name: String) -> NSImage {
        guard let source = NSImage(named: NSImage.Name(name)), let image = source.copy() as? NSImage else {
            preconditionFailure("Missing LCD material asset: \(name)")
        }
        return image
    }

    static func drawPanel(_ image: NSImage, in bounds: NSRect) {
        let left: CGFloat = 13
        let right: CGFloat = 13
        let top: CGFloat = 20
        let bottom: CGFloat = 6
        let size = image.size
        // Image source coordinates are bottom-up; destination views are flipped.
        let sourceX: [CGFloat] = [0, left, size.width - right]
        let sourceY: [CGFloat] = [size.height - top, bottom, 0]
        let sourceWidths: [CGFloat] = [left, size.width - left - right, right]
        let sourceHeights: [CGFloat] = [top, size.height - top - bottom, bottom]
        let targetX: [CGFloat] = [bounds.minX, bounds.minX + left, bounds.maxX - right]
        let targetY: [CGFloat] = [bounds.minY, bounds.minY + top, bounds.maxY - bottom]
        let targetWidths: [CGFloat] = [left, max(0, bounds.width - left - right), right]
        let targetHeights: [CGFloat] = [top, max(0, bounds.height - top - bottom), bottom]
        for row in 0..<3 {
            for column in 0..<3 {
                let source = NSRect(x: sourceX[column], y: sourceY[row],
                                    width: sourceWidths[column], height: sourceHeights[row])
                let target = NSRect(x: targetX[column], y: targetY[row],
                                    width: targetWidths[column], height: targetHeights[row])
                image.draw(in: target, from: source, operation: .sourceOver,
                           fraction: 1, respectFlipped: true, hints: nil)
            }
        }
    }

    private static func color(_ rgb: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 0xff) / 255,
                green: CGFloat((rgb >> 8) & 0xff) / 255,
                blue: CGFloat(rgb & 0xff) / 255, alpha: alpha)
    }
}
