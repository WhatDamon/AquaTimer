import AppKit

/// Native momentary button with the approved Finder-style optical layers.
@MainActor
final class AquaActionButton: NSButton, AquaFocusTarget {
    enum Role: String {
        case primary = "Primary"
        case reset = "Reset"

        var bodyWidth: CGFloat { 168 }
    }

    enum Icon: String, CaseIterable {
        case play = "Play"
        case pause = "Pause"
        case reset = "Reset"
    }

    static let focusPadding: CGFloat = 4
    private static let hitHeight: CGFloat = 44
    let role: Role
    var icon: Icon {
        didSet { if oldValue != icon { needsDisplay = true } }
    }
    private let normalImage: NSImage
    private let hoverImage: NSImage
    private let pressedImage: NSImage
    private let disabledImage: NSImage
    private let iconImages: [Icon: NSImage]
    private let disabledIconImages: [Icon: NSImage]
    private let helpTag = AquaHelpTag()
    private var hoverArea: NSTrackingArea?
    private var isHovered = false

    init(title: String, role: Role, icon: Icon) {
        self.role = role
        self.icon = icon
        let prefix = "AquaAction\(role.rawValue)"
        normalImage = Self.loadImage(prefix + "Normal")
        hoverImage = Self.loadImage(prefix + "Hover")
        pressedImage = Self.loadImage(prefix + "Pressed")
        disabledImage = Self.loadImage(prefix + "Disabled")
        iconImages = Dictionary(uniqueKeysWithValues: Icon.allCases.map {
            ($0, Self.loadImage("AquaActionIcon\($0.rawValue)"))
        })
        disabledIconImages = Dictionary(uniqueKeysWithValues: Icon.allCases.map {
            ($0, Self.loadImage("AquaActionIcon\($0.rawValue)Disabled"))
        })
        super.init(frame: .zero)
        self.title = title
        setAccessibilityLabel(title)
        setButtonType(.momentaryPushIn)
        isBordered = false
        focusRingType = .none
        font = AquaTypography.font(ofSize: 13)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: role.bodyWidth + Self.focusPadding * 2),
            heightAnchor.constraint(equalToConstant: Self.hitHeight)
        ])
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var intrinsicContentSize: NSSize {
        NSSize(width: role.bodyWidth + Self.focusPadding * 2, height: Self.hitHeight)
    }
    override var title: String {
        didSet {
            setAccessibilityLabel(title)
            updateShortcutHelp()
            needsDisplay = true
        }
    }
    override var isEnabled: Bool {
        didSet {
            if !isEnabled { helpTag.dismiss() }
            needsDisplay = true
        }
    }

    var aquaFocusGeometry: AquaFocusGeometry {
        AquaFocusGeometry(rect: bodyRect, shape: .roundedRect(4.6))
    }

    private var bodyRect: NSRect {
        NSRect(x: Self.focusPadding, y: bounds.midY - 14, width: role.bodyWidth, height: 28)
    }

    private func updateShortcutHelp() {
        let shortcut = role == .primary ? "Return" : "⌘R"
        let help = "\(title)（\(shortcut)）"
        helpTag.text = help
        setAccessibilityHelp(help)
    }

    override func draw(_ dirtyRect: NSRect) {
        let artwork: NSImage
        if !isEnabled {
            artwork = disabledImage
        } else if isHighlighted {
            artwork = pressedImage
        } else if isHovered && window?.isKeyWindow == true {
            artwork = hoverImage
        } else {
            artwork = normalImage
        }
        draw(artwork, in: bodyRect.insetBy(dx: -Self.focusPadding, dy: -Self.focusPadding))

        let body = bodyRect
        let shift: CGFloat = isHighlighted && isEnabled ? 0.3 : 0
        let textFont = font ?? AquaTypography.font(ofSize: 13)
        let text = NSAttributedString(string: title, attributes: [
            .font: textFont,
            .foregroundColor: NSColor(calibratedWhite: isEnabled ? 65.0 / 255 : 170.0 / 255, alpha: 1)
        ])
        let groupWidth = 14 + 6 + text.size().width
        let left = body.midX - groupWidth / 2
        if let iconImage = (isEnabled ? iconImages : disabledIconImages)[icon] {
            // Each 14 pt glyph has 2 pt transparent padding for its own soft shadow.
            draw(iconImage, in: NSRect(x: left - 2, y: body.minY + 5 + shift, width: 18, height: 18))
        }
        text.draw(at: NSPoint(x: left + 20, y: body.minY + 18.5 - textFont.ascender + shift))

    }

    private func draw(_ image: NSImage, in rect: NSRect) {
        image.draw(in: rect, from: .zero, operation: .sourceOver,
                   fraction: 1, respectFlipped: true, hints: nil)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        hoverArea = area
        if let window {
            isHovered = bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
        }
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        helpTag.attach(to: self)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        if let window {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(windowFocusChanged),
                                                       name: name, object: window)
            }
        }
        needsDisplay = true
    }

    @objc private func windowFocusChanged() { needsDisplay = true }

    private static func loadImage(_ name: String) -> NSImage {
        guard let image = NSImage(named: NSImage.Name(name)) else {
            preconditionFailure("Missing Aqua action-button asset: \(name)")
        }
        return image
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AquaActionButton uses programmatic initialization.")
    }
}
