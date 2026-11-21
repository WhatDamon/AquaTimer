import AppKit

@MainActor
final class WindowTitlebarView: NSView {
    private let titleLabel = NSTextField(labelWithString: "AquaTimer")
    private let windowButtons: AquaWindowButtonGroup
    private let showsTitle: Bool

    init(purpose: AquaWindowButtonGroup.Purpose = .timer) {
        windowButtons = AquaWindowButtonGroup(purpose: purpose)
        showsTitle = purpose != .about
        super.init(frame: .zero)
        titleLabel.isHidden = !showsTitle
        titleLabel.font = AquaTypography.font(ofSize: 13)
        titleLabel.alignment = .center
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        updateTitle("AquaTimer")

        let buttons = windowButtons
        buttons.translatesAutoresizingMaskIntoConstraints = false
        addSubview(buttons)
        NSLayoutConstraint.activate([
            buttons.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            buttons.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: buttons.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -80)
        ])
    }

    func updateTitle(_ title: String) {
        guard showsTitle else { return }
        let highlight = NSShadow()
        highlight.shadowColor = NSColor.white.withAlphaComponent(0.78)
        highlight.shadowOffset = NSSize(width: 0, height: -1)
        highlight.shadowBlurRadius = 0
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        // A single accessible text field draws a crisp white impression beneath the dark glyphs.
        titleLabel.attributedStringValue = NSAttributedString(string: title, attributes: [
            .font: AquaTypography.font(ofSize: 13),
            .foregroundColor: NSColor(calibratedWhite: 0.12, alpha: 1),
            .paragraphStyle: paragraph,
            .shadow: highlight
        ])
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let hit = super.hitTest(point)
        return hit === titleLabel ? self : hit
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
            case "Minimize":
                if window?.styleMask.contains(.miniaturizable) == true { window?.performMiniaturize(nil) }
            case "None": break
            default: break
            }
        } else {
            window?.performDrag(with: event)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("WindowTitlebarView uses programmatic initialization.")
    }
}
