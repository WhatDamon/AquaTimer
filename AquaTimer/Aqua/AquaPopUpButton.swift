import AppKit

/// Keeps AppKit's pop-up selection model and draws the standard Aqua appearance.
@MainActor
final class AquaPopUpButton: NSPopUpButton, AquaFocusTarget {
    static let faceWidth: CGFloat = 190
    static let faceHeight: CGFloat = 20
    static let capWidth: CGFloat = 20
    static let textInset: CGFloat = 9
    static let baseline: CGFloat = 14.3
    private static let controlHeight: CGFloat = 26
    private var presentation: AquaPopUpMenuPresentation?

    init() {
        super.init(frame: .zero, pullsDown: false)
        font = AquaTypography.font(ofSize: 13)
        focusRingType = .none
        isBordered = false
        setAccessibilityElement(true)
        setAccessibilityRole(.popUpButton)
    }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.faceWidth, height: Self.controlHeight)
    }
    override var firstBaselineOffsetFromTop: CGFloat { (Self.controlHeight - Self.faceHeight) / 2 + Self.baseline }
    override var lastBaselineOffsetFromBottom: CGFloat { Self.controlHeight - firstBaselineOffsetFromTop }
    override var isEnabled: Bool {
        didSet {
            if !isEnabled { presentation?.dismiss() }
            needsDisplay = true
        }
    }

    var aquaFocusGeometry: AquaFocusGeometry { AquaFocusGeometry(rect: face, shape: .roundedRect(4.5)) }
    var aquaFocusIsEnabled: Bool { isEnabled && presentation == nil }
    var face: NSRect {
        NSRect(x: bounds.minX, y: bounds.midY - Self.faceHeight / 2, width: bounds.width, height: Self.faceHeight)
    }

    override func draw(_ dirtyRect: NSRect) {
        let image = NSImage(named: isEnabled ? "AquaPopupClosed" : "AquaPopupDisabled")
        image?.draw(in: face.insetBy(dx: 0, dy: -2), from: .zero, operation: .sourceOver,
                    fraction: 1, respectFlipped: true, hints: nil)
        guard let title = selectedItem?.title else { return }
        let textFont = font ?? AquaTypography.font(ofSize: 13)
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let label = NSAttributedString(string: title, attributes: [
            .font: textFont,
            .foregroundColor: AquaGlassMaterial.color(isEnabled ? 0x252930 : 0x8b9098),
            .paragraphStyle: style
        ])
        let textRect = NSRect(x: face.minX + Self.textInset, y: face.minY + Self.baseline - textFont.ascender,
                              width: max(0, face.width - Self.capWidth - Self.textInset * 2), height: 18)
        label.draw(in: textRect)
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow !== window { presentation?.dismiss() }
        super.viewWillMove(toWindow: newWindow)
    }

    override func mouseDown(with event: NSEvent) { showMenu(openingWithMouse: true) }
    override func performClick(_ sender: Any?) { showMenu() }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 36, 49, 76, 125, 126: showMenu() // Return, Space, Enter, Down, Up
        default: super.keyDown(with: event)
        }
    }

    override func accessibilityPerformPress() -> Bool { showMenu() }
    override func accessibilityPerformShowMenu() -> Bool { showMenu() }
    override func accessibilityValue() -> Any? { selectedItem?.title }
    override func isAccessibilityExpanded() -> Bool { presentation != nil }
    override func accessibilityChildren() -> [Any]? {
        // Keep AppKit's separate native menu from being exposed beside the visible menu.
        if let presentation { return [presentation.menuView] }
        return []
    }

    @discardableResult
    private func showMenu(openingWithMouse: Bool = false) -> Bool {
        guard isEnabled, let window, numberOfItems > 0 else { return false }
        if let presentation { presentation.dismiss(); return true }
        window.makeFirstResponder(self)
        let menu = AquaPopUpMenuPresentation(button: self, owner: window, openingWithMouse: openingWithMouse)
        presentation = menu
        menu.show()
        NSAccessibility.post(element: self, notification: .layoutChanged)
        return true
    }

    func menuDidDismiss(_ menu: AquaPopUpMenuPresentation, selection: Int?) {
        guard presentation === menu else { return }
        presentation = nil
        guard let selection, isEnabled, item(at: selection)?.isEnabled == true,
              indexOfSelectedItem != selection else {
            NSAccessibility.post(element: self, notification: .layoutChanged)
            return
        }
        selectItem(at: selection)
        needsDisplay = true
        sendAction(action, to: target)
        NSAccessibility.post(element: self, notification: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("AquaPopUpButton uses programmatic initialization.") }
}
