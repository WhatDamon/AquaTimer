import AppKit

@MainActor
final class SettingsToolbarToggle: NSButton, AquaFocusTarget {
    private let helpTag = AquaHelpTag()
    private let expandedArtwork = NSImage(named: NSImage.Name("AquaToolbarToggleExpanded"))
    private let pressedArtwork = NSImage(named: NSImage.Name("AquaToolbarTogglePressed"))
    private let collapsedArtwork = NSImage(named: NSImage.Name("AquaToolbarToggleCollapsed"))

    var isToolbarVisible = true {
        didSet { updatePresentation() }
    }

    init() {
        super.init(frame: .zero)
        setButtonType(.momentaryChange)
        isBordered = false
        focusRingType = .none
        setAccessibilityIdentifier("Settings.ToolbarToggle")
        updatePresentation()
    }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: 28, height: 22) }

    private var artworkRect: NSRect {
        NSRect(x: bounds.midX - 10, y: bounds.midY - 5, width: 20, height: 10)
    }

    var aquaFocusGeometry: AquaFocusGeometry {
        AquaFocusGeometry(rect: artworkRect, shape: .roundedRect(5))
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        helpTag.attach(to: self)
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let image = isHighlighted ? pressedArtwork : (isToolbarVisible ? expandedArtwork : collapsedArtwork)
        image?.draw(in: artworkRect, from: .zero, operation: .sourceOver,
                    fraction: 1, respectFlipped: true, hints: nil)
    }

    private func updatePresentation() {
        let actionTitle = isToolbarVisible ? "隐藏工具栏" : "显示工具栏"
        helpTag.text = actionTitle
        setAccessibilityLabel(actionTitle)
        setAccessibilityExpanded(isToolbarVisible)
        needsDisplay = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("SettingsToolbarToggle uses programmatic initialization.") }
}
