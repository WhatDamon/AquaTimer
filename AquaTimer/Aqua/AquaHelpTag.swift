import AppKit

/// Delayed, noninteractive help for icon-only controls and status indicators.
@MainActor
final class AquaHelpTag: NSResponder {
    private weak var anchor: NSView?
    private var trackingArea: NSTrackingArea?
    private var timer: Timer?
    private var eventMonitor: Any?
    private var panel: HelpTagPanel?

    var text: String? {
        didSet {
            guard oldValue != text else { return }
            if text == nil { dismiss() }
            else if panel != nil { show() }
        }
    }

    func attach(to view: NSView) {
        dismiss()
        if let trackingArea { anchor?.removeTrackingArea(trackingArea) }
        trackingArea = nil
        NotificationCenter.default.removeObserver(self)
        anchor = view
        guard let window = view.window else { return }

        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        view.addTrackingArea(area)
        trackingArea = area
        let center = NotificationCenter.default
        for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification,
                     NSWindow.willMiniaturizeNotification, NSWindow.didMoveNotification,
                     NSWindow.didResizeNotification] {
            center.addObserver(self, selector: #selector(dismiss), name: name, object: window)
        }
        center.addObserver(self, selector: #selector(dismiss), name: NSApplication.didResignActiveNotification,
                           object: NSApp)
        center.addObserver(self, selector: #selector(dismiss), name: NSMenu.didBeginTrackingNotification,
                           object: nil)
    }

    override func mouseEntered(with event: NSEvent) {
        guard event.trackingArea === trackingArea, text != nil,
              (anchor as? NSControl)?.isEnabled != false else { return }
        dismiss()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .leftMouseDragged, .rightMouseDragged, .otherMouseDragged, .scrollWheel, .keyDown
        ]) { [weak self] event in
            self?.dismiss()
            return event
        }
        schedule(#selector(show), after: 1.2)
    }

    override func mouseExited(with event: NSEvent) {
        if event.trackingArea === trackingArea { dismiss() }
    }

    @objc func dismiss() {
        timer?.invalidate()
        timer = nil
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        panel?.hide()
        panel = nil
    }

    @objc private func show() {
        guard let text, let anchor, let window = anchor.window,
              window.isVisible, window.isKeyWindow, NSApp.isActive,
              !anchor.isHiddenOrHasHiddenAncestor, (anchor as? NSControl)?.isEnabled != false,
              NSEvent.pressedMouseButtons == 0 else {
            dismiss()
            return
        }
        let pointer = NSEvent.mouseLocation
        let localPointer = anchor.convert(window.convertPoint(fromScreen: pointer), from: nil)
        guard anchor.bounds.intersection(anchor.visibleRect).contains(localPointer),
              let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? window.screen else {
            dismiss()
            return
        }

        let tag = panel ?? HelpTagPanel()
        tag.show(text, at: pointer, on: screen, in: window)
        if panel == nil { schedule(#selector(dismiss), after: 10) }
        panel = tag
    }

    private func schedule(_ action: Selector, after interval: TimeInterval) {
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, target: self, selector: action, userInfo: nil, repeats: false)
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

@MainActor
private final class HelpTagPanel: NSPanel {
    private let label = NSTextField(labelWithString: "")
    private lazy var shadow = TigerWindowShadow(owner: self, shape: .square, profile: .helpTag)

    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
                   styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = true
        backgroundColor = AquaGlassMaterial.color(0xfff6c7)
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        animationBehavior = .none
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        setAccessibilityElement(false)
        let surface = NSView()
        surface.wantsLayer = true
        surface.layer?.backgroundColor = backgroundColor.cgColor
        surface.layer?.borderColor = AquaGlassMaterial.color(0xb0a375).cgColor
        surface.layer?.borderWidth = 1
        surface.setAccessibilityHidden(true)
        contentView = surface
        label.font = AquaTypography.font(ofSize: 11)
        label.textColor = AquaGlassMaterial.color(0x252218)
        surface.addSubview(label)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    func show(_ text: String, at pointer: NSPoint, on screen: NSScreen, in owner: NSWindow) {
        label.stringValue = text
        label.sizeToFit()
        label.frame.origin = NSPoint(x: 4, y: 2)
        let size = NSSize(width: ceil(label.frame.width) + 8, height: ceil(label.frame.height) + 4)
        let visible = screen.visibleFrame.insetBy(dx: 4, dy: 4)
        let x = min(max(pointer.x + 6, visible.minX), visible.maxX - size.width)
        let below = pointer.y - size.height - 18
        let y = below >= visible.minY ? below : min(pointer.y + 12, visible.maxY - size.height)
        setFrame(NSRect(x: floor(x), y: floor(y), width: size.width, height: size.height), display: true)
        if parent == nil {
            level = owner.level
            shadow.level = level
            addChildWindow(shadow, ordered: .below)
            owner.addChildWindow(self, ordered: .above)
            order(.above, relativeTo: owner.windowNumber)
            shadow.order(.below, relativeTo: windowNumber)
        }
        shadow.synchronize(with: self)
    }

    func hide() {
        parent?.removeChildWindow(self)
        removeChildWindow(shadow)
        shadow.orderOut(nil)
        orderOut(nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("HelpTagPanel uses programmatic initialization.") }
}
