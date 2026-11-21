import AppKit

@MainActor
final class LCDGlassView: NSView {
    private let optics: NSImage

    init() {
        optics = LCDMaterial.image(named: "LCDGlass")
        super.init(frame: .zero)
        setAccessibilityElement(false)
        setAccessibilityHidden(true)
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        LCDMaterial.drawPanel(optics, in: bounds)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LCDGlassView uses programmatic initialization.")
    }
}
