import AppKit

/// A text-only momentary button for standard Aqua windows.
@MainActor
final class AquaPushButton: NSButton, AquaFocusTarget {
    private static let faceHeight: CGFloat = 20
    private static let controlHeight: CGFloat = 26
    private static let baseline: CGFloat = 14.3
    private let isDefaultAction: Bool
    var defaultPulseAmount: CGFloat = 0 {
        didSet { if oldValue != defaultPulseAmount { needsDisplay = true } }
    }

    init(label: String, isDefaultAction: Bool = false) {
        self.isDefaultAction = isDefaultAction
        super.init(frame: .zero)
        title = label
        setButtonType(.momentaryPushIn)
        isBordered = false
        focusRingType = .none
        font = AquaTypography.font(ofSize: 13)
    }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override var firstBaselineOffsetFromTop: CGFloat { (Self.controlHeight - Self.faceHeight) / 2 + Self.baseline }
    override var lastBaselineOffsetFromBottom: CGFloat { Self.controlHeight - firstBaselineOffsetFromTop }
    override var intrinsicContentSize: NSSize {
        NSSize(width: max(68, ceil(label().size().width) + 28), height: Self.controlHeight)
    }
    override var title: String {
        didSet {
            setAccessibilityLabel(title)
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    override var isEnabled: Bool { didSet { needsDisplay = true } }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    var aquaFocusGeometry: AquaFocusGeometry {
        AquaFocusGeometry(rect: face, shape: .roundedRect(radius))
    }

    private var face: NSRect {
        NSRect(x: bounds.minX, y: bounds.midY - Self.faceHeight / 2,
               width: bounds.width, height: Self.faceHeight)
    }
    private var radius: CGFloat { min(face.width, face.height) / 2 }

    override func draw(_ dirtyRect: NSRect) {
        guard !face.isEmpty else { return }
        let pressed = isEnabled && isHighlighted
        let outline = CGPath(roundedRect: face, cornerWidth: radius, cornerHeight: radius, transform: nil)
        let palette = if !isEnabled {
            AquaGlassMaterial.disabled
        } else if pressed || isDefaultAction {
            AquaGlassMaterial.blue
        } else {
            AquaGlassMaterial.clear
        }
        AquaGlassMaterial.draw(in: face, outline: outline, palette: palette, pressed: pressed)
        if isDefaultAction && isEnabled && !pressed && defaultPulseAmount > 0,
           let context = NSGraphicsContext.current?.cgContext {
            context.saveGState()
            context.setFillColor(AquaGlassMaterial.color(0xf5faff, alpha: defaultPulseAmount * 0.42).cgColor)
            context.addPath(outline)
            context.fillPath()
            context.restoreGState()
        }
        let text = label()
        let baseline = face.minY + Self.baseline + (pressed ? 0.25 : 0)
        text.draw(at: NSPoint(x: face.midX - text.size().width / 2, y: baseline - titleFont.ascender))
    }

    private var titleFont: NSFont { font ?? AquaTypography.font(ofSize: 13) }

    private func label() -> NSAttributedString {
        let ink: UInt32 = isEnabled ? (isHighlighted ? 0x203247 : 0x202226) : 0x91979d
        return NSAttributedString(string: title, attributes: [
            .font: titleFont,
            .foregroundColor: AquaGlassMaterial.color(ink)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("AquaPushButton uses programmatic initialization.") }
}
