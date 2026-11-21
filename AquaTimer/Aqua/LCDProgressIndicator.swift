import AppKit

@MainActor
final class LCDProgressIndicator: NSProgressIndicator {
    private static let segmentCount = 24
    private static let gap: CGFloat = 2

    override var doubleValue: Double {
        didSet { if oldValue != doubleValue { needsDisplay = true } }
    }

    override func draw(_ dirtyRect: NSRect) {
        let range = maxValue - minValue
        let fraction = range > 0 ? max(0, min(1, (doubleValue - minValue) / range)) : 0
        let activeCount = Int(floor(fraction * Double(Self.segmentCount)))
        let segmentWidth = (bounds.width - Self.gap * CGFloat(Self.segmentCount - 1))
            / CGFloat(Self.segmentCount)
        guard segmentWidth > 0 else { return }
        let scale = window?.backingScaleFactor ?? 2
        for index in 0..<Self.segmentCount {
            let start = bounds.minX + CGFloat(index) * (segmentWidth + Self.gap)
            let left = (start * scale).rounded() / scale
            let right = ((start + segmentWidth) * scale).rounded() / scale
            (index < activeCount ? LCDMaterial.ink : LCDMaterial.inactiveInk).setFill()
            NSRect(x: left, y: bounds.minY, width: right - left, height: bounds.height).fill()
        }
    }

    override var allowsVibrancy: Bool { false }
}
