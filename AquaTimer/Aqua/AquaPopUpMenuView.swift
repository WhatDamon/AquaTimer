import AppKit

/// A square, striped menu surface with a selected row over the pop-up button.
@MainActor
final class AquaPopUpMenuView: NSView {
    static let shadowInset: CGFloat = 22
    static let leftOutset: CGFloat = 11.5
    static let rowTopInset: CGFloat = 2.5
    private static let rowHeight = AquaPopUpButton.faceHeight

    let selected: Int
    let face: NSRect
    var choose: ((Int) -> Void)?
    private var rows: [MenuRow] = []
    private let items: [NSMenuItem]
    var highlighted: Int? {
        didSet {
            guard highlighted != oldValue else { return }
            for (index, row) in rows.enumerated() { row.showsHighlight = index == highlighted }
        }
    }

    init(items: [NSMenuItem], selected: Int, width: CGFloat, font: NSFont) {
        self.items = items
        self.selected = selected
        self.highlighted = items.indices.contains(selected) && items[selected].isEnabled ? selected : nil
        self.face = NSRect(x: Self.shadowInset, y: Self.shadowInset, width: width,
                           height: CGFloat(items.count) * Self.rowHeight + Self.rowTopInset * 2)
        super.init(frame: NSRect(origin: .zero, size: face.insetBy(dx: -Self.shadowInset, dy: -Self.shadowInset).size))
        appearance = NSAppearance(named: .aqua)
        setAccessibilityElement(true)
        setAccessibilityRole(.menu)
        for (index, item) in items.enumerated() {
            let row = MenuRow(title: item.title, font: font, selected: index == selected)
            row.frame = NSRect(x: face.minX + 0.5, y: face.minY + Self.rowTopInset + CGFloat(index) * Self.rowHeight,
                               width: face.width - 1, height: Self.rowHeight)
            row.isEnabled = item.isEnabled
            row.showsHighlight = index == highlighted
            row.tag = index
            row.target = self
            row.action = #selector(chooseRow(_:))
            rows.append(row)
            addSubview(row)
        }
    }

    override var isFlipped: Bool { true }
    override func accessibilityChildren() -> [Any]? { rows }

    @objc private func chooseRow(_ sender: NSButton) { choose?(sender.tag) }

    func index(at point: NSPoint) -> Int? {
        guard let index = rows.firstIndex(where: { $0.frame.contains(point) }), items[index].isEnabled else { return nil }
        return index
    }

    func moveHighlight(by step: Int) {
        var index = highlighted ?? (step > 0 ? -1 : items.count)
        repeat { index += step } while items.indices.contains(index) && !items[index].isEnabled
        if items.indices.contains(index) { highlighted = index }
    }

    func highlightPrefix(_ text: String) {
        if let index = items.firstIndex(where: { $0.isEnabled && $0.title.lowercased().hasPrefix(text.lowercased()) }) {
            highlighted = index
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        // Short and broad layers keep the same proportions as the menu sample.
        for (blur, offset, opacity): (CGFloat, CGFloat, CGFloat) in [(9.6, 4.2, 0.42), (2.9, 1.3, 0.29)] {
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = .black.withAlphaComponent(opacity)
            shadow.shadowOffset = NSSize(width: 0, height: -offset)
            shadow.shadowBlurRadius = blur
            shadow.set()
            NSColor.black.setFill()
            face.fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        AquaGlassMaterial.color(0xf5f5f5).setFill()
        face.fill()
        AquaGlassMaterial.color(0xefefef).setFill()
        for y in stride(from: face.minY, to: face.maxY, by: 2) {
            NSRect(x: face.minX, y: y, width: face.width, height: 1).fill()
        }
        AquaGlassMaterial.color(0xbfc3c7).setStroke()
        let border = NSBezierPath(rect: face.insetBy(dx: 0.35, dy: 0.35))
        border.lineWidth = 0.7
        border.stroke()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("AquaPopUpMenuView uses programmatic initialization.") }

    @MainActor
    private final class MenuRow: NSButton {
        private let marksSelection: Bool
        private let titleFont: NSFont
        var showsHighlight = false { didSet { needsDisplay = true } }

        init(title: String, font: NSFont, selected: Bool) {
            marksSelection = selected
            titleFont = font
            super.init(frame: .zero)
            self.title = title
            isBordered = false
            setAccessibilityElement(true)
            setAccessibilityRole(.menuItem)
            setAccessibilityLabel(title)
            setAccessibilitySelected(selected)
        }

        override var isFlipped: Bool { true }
        override var acceptsFirstResponder: Bool { false }
        override func accessibilityPerformPress() -> Bool {
            guard isEnabled else { return false }
            return sendAction(action, to: target)
        }

        override func draw(_ dirtyRect: NSRect) {
            if showsHighlight {
                NSGradient(starting: AquaGlassMaterial.color(0x487ec7), ending: AquaGlassMaterial.color(0x3164ab))?
                    .draw(in: bounds, angle: 90)
            }
            let ink = AquaGlassMaterial.color(showsHighlight ? 0xffffff : (isEnabled ? 0x23262b : 0x8b9098))
            if marksSelection, let check = NSImage(named: showsHighlight ? "AquaPopupCheckLight" : "AquaPopupCheckDark") {
                check.draw(in: NSRect(x: 3, y: 5.25, width: 11, height: 10), from: .zero,
                           operation: .sourceOver, fraction: isEnabled ? 1 : 0.45, respectFlipped: true, hints: nil)
            }
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            let label = NSAttributedString(string: title, attributes: [
                .font: titleFont, .foregroundColor: ink, .paragraphStyle: style
            ])
            let left = AquaPopUpMenuView.leftOutset + AquaPopUpButton.textInset - 0.5
            let textRect = NSRect(x: left, y: AquaPopUpButton.baseline - titleFont.ascender,
                                  width: max(0, bounds.width - left - 7), height: 18)
            label.draw(in: textRect)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("MenuRow uses programmatic initialization.") }
    }
}
