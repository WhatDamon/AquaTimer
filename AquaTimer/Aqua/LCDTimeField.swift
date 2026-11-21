import AppKit
import CoreText

/// Fixed electrodes share one baseline and advance widths for every displayed value.
@MainActor
final class LCDTimeField: NSTextField {
    private static let electrodes = "88:88:88"

    init() {
        super.init(frame: .zero)
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
        usesSingleLineMode = true
        font = AquaTypography.lcdFont(ofSize: 54)
        textColor = LCDMaterial.ink
        stringValue = "00:25:00"
        setAccessibilityLabel("剩余时间")
        setAccessibilityIdentifier("Timer.Remaining")
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }

    override var stringValue: String {
        get { super.stringValue }
        set {
            guard newValue != super.stringValue else { return }
            super.stringValue = newValue
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        let font = font ?? AquaTypography.lcdFont(ofSize: 54)
        let size = NSAttributedString(string: Self.electrodes, attributes: [.font: font]).size()
        return NSSize(width: ceil(size.width) + 4, height: ceil(font.pointSize) + 12)
    }

    func showTime(_ seconds: TimeInterval?) {
        guard let seconds, seconds.isFinite else {
            stringValue = "--:--:--"
            return
        }
        let value = CountdownDuration.display(seconds)
        stringValue = value.count == 5 ? "00:\(value)" : value
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let font = font ?? AquaTypography.lcdFont(ofSize: 54)
        let inactive = CTLineCreateWithAttributedString(NSAttributedString(
            string: Self.electrodes, attributes: [.font: font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): LCDMaterial.inactiveInk.cgColor]
        ))
        let active = CTLineCreateWithAttributedString(NSAttributedString(
            string: stringValue, attributes: [.font: font, NSAttributedString.Key(kCTForegroundColorAttributeName as String): LCDMaterial.ink.cgColor]
        ))
        let width = CGFloat(CTLineGetTypographicBounds(inactive, nil, nil, nil))
        let ascent = CTFontGetAscent(font as CTFont)
        let descent = CTFontGetDescent(font as CTFont)
        let baseline = (bounds.height - ascent - descent) / 2 + ascent
        context.saveGState()
        context.clip(to: bounds)
        context.translateBy(x: (bounds.width - width) / 2, y: baseline)
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity
        context.textPosition = .zero
        CTLineDraw(inactive, context)
        context.textPosition = .zero
        CTLineDraw(active, context)
        context.restoreGState()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LCDTimeField uses programmatic initialization.")
    }
}
