import AppKit

/// The visual contour of an interactive control, in its own coordinate space.
struct AquaFocusGeometry: Equatable {
    enum Shape: Equatable {
        case ellipse
        case roundedRect(CGFloat)
    }

    let rect: NSRect
    let shape: Shape
}

@MainActor
protocol AquaFocusTarget: AnyObject {
    var aquaFocusGeometry: AquaFocusGeometry { get }
    var aquaFocusIsEnabled: Bool { get }
    func ownsAquaFocus(_ responder: NSResponder) -> Bool
}

extension AquaFocusTarget where Self: NSView {
    var aquaFocusIsEnabled: Bool { (self as? NSControl)?.isEnabled ?? true }
    func ownsAquaFocus(_ responder: NSResponder) -> Bool { responder === self }
}

/// One renderer supplies the same stroke, outset and soft halo for every control shape.
@MainActor
enum AquaFocusRing {
    static func draw(_ geometry: AquaFocusGeometry, increaseContrast: Bool) {
        NSGraphicsContext.saveGraphicsState()
        let halo = path(for: geometry, outset: 1.25)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(calibratedRed: 89.0 / 255, green: 164.0 / 255,
                                     blue: 207.0 / 255, alpha: increaseContrast ? 0.85 : 0.65)
        shadow.shadowOffset = .zero
        shadow.shadowBlurRadius = 1.3
        shadow.set()
        NSColor(calibratedRed: 89.0 / 255, green: 164.0 / 255,
                blue: 207.0 / 255, alpha: increaseContrast ? 0.8 : 0.45).setStroke()
        halo.lineWidth = increaseContrast ? 2.8 : 2.2
        halo.stroke()
        NSGraphicsContext.restoreGraphicsState()

        NSGraphicsContext.saveGraphicsState()
        let outline = path(for: geometry, outset: 0.9)
        if increaseContrast {
            NSColor(calibratedRed: 39.0 / 255, green: 112.0 / 255,
                    blue: 158.0 / 255, alpha: 1).setStroke()
        } else {
            NSColor(calibratedRed: 123.0 / 255, green: 183.0 / 255,
                    blue: 220.0 / 255, alpha: 0.92).setStroke()
        }
        outline.lineWidth = increaseContrast ? 2 : 1.6
        outline.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func path(for geometry: AquaFocusGeometry, outset: CGFloat) -> NSBezierPath {
        let rect = geometry.rect.insetBy(dx: -outset, dy: -outset)
        switch geometry.shape {
        case .ellipse:
            return NSBezierPath(ovalIn: rect)
        case .roundedRect(let radius):
            return NSBezierPath(roundedRect: rect, xRadius: radius + outset, yRadius: radius + outset)
        }
    }
}

/// Paint above the whole window so small controls and text-editor hosts cannot clip their halo.
@MainActor
final class AquaFocusRingOverlay: NSView {
    private struct Presentation: Equatable {
        let geometry: AquaFocusGeometry
        let increaseContrast: Bool
    }

    private var presentation: Presentation?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(false)
        setAccessibilityHidden(true)
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        guard let presentation else { return }
        AquaFocusRing.draw(presentation.geometry, increaseContrast: presentation.increaseContrast)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        if let window {
            for name in [NSWindow.didUpdateNotification, NSWindow.didBecomeKeyNotification,
                         NSWindow.didResignKeyNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: name, object: window)
            }
            for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(refresh), name: name, object: NSApp)
            }
            NSWorkspace.shared.notificationCenter.addObserver(
                self, selector: #selector(refresh), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
                object: nil
            )
        }
        refresh()
    }

    override func layout() {
        super.layout()
        refresh()
    }

    @objc private func refresh() {
        let next: Presentation?
        if let window, window.isKeyWindow, NSApp.isActive,
           let root = window.contentView, let responder = window.firstResponder,
           let match = focusTarget(in: root, responder: responder) {
            let local = match.target.aquaFocusGeometry
            next = Presentation(
                geometry: AquaFocusGeometry(rect: match.view.convert(local.rect, to: self), shape: local.shape),
                increaseContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
            )
        } else {
            next = nil
        }
        guard next != presentation else { return }
        presentation = next
        needsDisplay = true
    }

    private func focusTarget(in view: NSView, responder: NSResponder)
        -> (view: NSView, target: any AquaFocusTarget)? {
        guard view !== self, !view.isHiddenOrHasHiddenAncestor else { return nil }
        if let target = view as? any AquaFocusTarget,
           target.aquaFocusIsEnabled, target.ownsAquaFocus(responder) {
            return (view, target)
        }
        for child in view.subviews {
            if let target = focusTarget(in: child, responder: responder) { return target }
        }
        return nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AquaFocusRingOverlay uses programmatic initialization.")
    }
}
