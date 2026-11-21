import AppKit

/// A passive child panel supplies the denser, downward shadow of a Tiger utility window.
/// It stays outside the timer's content and never intercepts input or takes focus.
@MainActor
final class TigerWindowShadow: NSPanel {
    enum Profile {
        case window
        case helpTag

        var padding: CGFloat { self == .window ? 40 : 12 }

        func layers(active: Bool) -> [(blur: CGFloat, offset: CGFloat, opacity: CGFloat)] {
            switch self {
            case .window: [(18, -7, active ? 0.38 : 0.23), (4, -2, active ? 0.22 : 0.13)]
            case .helpTag: [(5, -2, 0.28), (1.5, -1, 0.22)]
            }
        }
    }

    private let profile: Profile
    private let shadowView = ShadowView()

    init(owner: NSWindow, shape: TigerWindowShape = .rounded, profile: Profile = .window) {
        self.profile = profile
        super.init(contentRect: owner.frame.insetBy(dx: -profile.padding, dy: -profile.padding),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isFloatingPanel = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenNone, .fullScreenDisallowsTiling]
        contentView = shadowView
        shadowView.shape = shape
        shadowView.profile = profile
        setAccessibilityElement(false)
        shadowView.setAccessibilityElement(false)
        synchronize(with: owner)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        // The padding must be allowed beyond the screen edge. Constraining this
        // passive child independently moves its shadow away from its owner.
        frameRect
    }

    func synchronize(with owner: NSWindow) {
        let target = owner.frame.insetBy(dx: -profile.padding, dy: -profile.padding)
        if frame != target { setFrame(target, display: true) }
        shadowView.isActive = owner.isKeyWindow && NSApp.isActive
    }

    @MainActor
    private final class ShadowView: NSView {
        var shape = TigerWindowShape.rounded
        var profile = Profile.window
        var isActive = false {
            didSet { if oldValue != isActive { needsDisplay = true } }
        }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layerContentsRedrawPolicy = .duringViewResize
        }

        override func draw(_ dirtyRect: NSRect) {
            guard let context = NSGraphicsContext.current?.cgContext else { return }
            let silhouette = shape.path(in: bounds.insetBy(dx: profile.padding, dy: profile.padding))
            // A broad cast shadow and a tighter contact shadow follow the same silhouette.
            for (blur, offset, opacity) in profile.layers(active: isActive) {
                NSGraphicsContext.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(opacity)
                shadow.shadowBlurRadius = blur
                shadow.shadowOffset = NSSize(width: 0, height: offset)
                shadow.set()
                NSColor.black.setFill()
                context.addPath(silhouette)
                context.fillPath()
                NSGraphicsContext.restoreGraphicsState()
            }
            // Leave the window silhouette transparent so its antialiased edge gains no dark ring.
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setBlendMode(.clear)
            context.addPath(silhouette)
            context.fillPath()
            NSGraphicsContext.restoreGraphicsState()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("ShadowView uses programmatic initialization.") }
    }
}
