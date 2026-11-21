import AppKit

/// Native AppKit selection behavior with the approved Aqua indicator artwork.
@MainActor
final class AquaSelectionButton: NSButton, AquaFocusTarget {
    enum Kind: String {
        case radio = "Radio"
        case checkbox = "Check"
    }

    static let captionInset: CGFloat = 25
    private static let indicatorSize: CGFloat = 22
    private let kind: Kind

    init(label: String, kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        setButtonType(kind == .radio ? .radio : .switch)
        title = label
        font = AquaTypography.font(ofSize: 13)
        isBordered = false
        focusRingType = .none
    }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.captionInset + ceil(caption.size().width), height: Self.indicatorSize)
    }
    override var firstBaselineOffsetFromTop: CGFloat {
        Self.indicatorSize / 2 + (captionFont.ascender + captionFont.descender) / 2
    }
    override var lastBaselineOffsetFromBottom: CGFloat { Self.indicatorSize - firstBaselineOffsetFromTop }
    override var title: String {
        didSet {
            setAccessibilityLabel(title)
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }
    override var isEnabled: Bool { didSet { needsDisplay = true } }
    override var state: NSControl.StateValue { didSet { needsDisplay = true } }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    var aquaFocusGeometry: AquaFocusGeometry {
        // These are the face bounds in the source SVG, including its 2 pt export inset.
        let origin = indicator.origin
        switch kind {
        case .radio:
            return AquaFocusGeometry(rect: NSRect(x: origin.x + 3.2, y: origin.y + 2.65,
                                                  width: 15.6, height: 15.6), shape: .ellipse)
        case .checkbox:
            return AquaFocusGeometry(rect: NSRect(x: origin.x + 3.25, y: origin.y + 2.7,
                                                  width: 15.5, height: 15.5), shape: .roundedRect(1.8))
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let selected = state == .on
        let suffix = if !isEnabled {
            selected ? "DisabledOn" : "DisabledOff"
        } else if isHighlighted {
            "Pressed"
        } else {
            selected ? "On" : "Off"
        }
        let name = "AquaSelection\(kind.rawValue)\(suffix)"
        guard let image = NSImage(named: NSImage.Name(name)) else {
            preconditionFailure("Missing Aqua selection artwork: \(name)")
        }
        image.draw(in: indicator, from: .zero, operation: .sourceOver,
                   fraction: 1, respectFlipped: true, hints: nil)
        let baseline = bounds.midY - Self.indicatorSize / 2 + firstBaselineOffsetFromTop
        caption.draw(at: NSPoint(x: bounds.minX + Self.captionInset, y: baseline - captionFont.ascender))
    }

    private var indicator: NSRect {
        NSRect(x: bounds.minX, y: bounds.midY - Self.indicatorSize / 2,
               width: Self.indicatorSize, height: Self.indicatorSize)
    }
    private var captionFont: NSFont { font ?? AquaTypography.font(ofSize: 13) }
    private var caption: NSAttributedString {
        NSAttributedString(string: title, attributes: [
            .font: captionFont,
            .foregroundColor: isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("AquaSelectionButton uses programmatic initialization.") }
}
