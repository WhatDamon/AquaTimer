import AppKit

@MainActor
final class AquaWindowButtonGroup: NSStackView {
    enum Purpose { case timer, about, settings }
    private let purpose: Purpose
    private let buttons: [AquaWindowButton]
    private var hoverTrackingArea: NSTrackingArea?

    init(purpose: Purpose = .timer) {
        self.purpose = purpose
        buttons = AquaWindowButton.Role.allCases.map {
            AquaWindowButton(role: $0,
                             disabledArtworkOpacity: purpose == .timer ? 0.55 : 1)
        }
        super.init(frame: .zero)
        orientation = .horizontal
        spacing = 1.5
        alignment = .centerY
        buttons.forEach { addArrangedSubview($0) }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let center = NotificationCenter.default
        center.removeObserver(self)
        buttons.forEach { $0.target = window }
        if let window {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                         NSWindow.didBecomeMainNotification, NSWindow.didResignMainNotification,
                         MainWindowController.controlAreaDidChangeNotification] {
                center.addObserver(self, selector: #selector(windowStateChanged(_:)), name: name, object: window)
            }
            for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
                center.addObserver(self, selector: #selector(windowStateChanged(_:)), name: name, object: NSApp)
            }
        }
        updateWindowState()
        updateHoverState()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        // visibleRect can extend beyond this non-clipping stack on modern macOS.
        // An explicit intersection keeps the tracking area on the traffic lights.
        let tracking = NSTrackingArea(rect: hoverRect,
                                      options: [.mouseEnteredAndExited, .activeAlways],
                                      owner: self, userInfo: nil)
        addTrackingArea(tracking)
        hoverTrackingArea = tracking
        updateHoverState()
    }

    override func mouseEntered(with event: NSEvent) {
        setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovering(false)
    }

    @objc private func windowStateChanged(_ notification: Notification) {
        updateWindowState()
        updateHoverState()
    }

    private func updateWindowState() {
        let active = window.map { $0.isVisible && ($0.isKeyWindow || $0.isMainWindow) && NSApp.isActive } ?? false
        for button in buttons {
            button.isWindowActive = active
            guard let window else {
                button.isEnabled = false
                continue
            }
            switch button.role {
            case .close:
                button.isEnabled = window.styleMask.contains(.closable)
            case .minimize:
                button.isEnabled = window.styleMask.contains(.miniaturizable)
            case .zoom:
                if purpose != .timer {
                    button.isEnabled = false
                    button.setAccessibilityLabel("缩放")
                    button.setAccessibilitySubrole(.zoomButton)
                    button.updateControlAreaHelp(nil)
                    continue
                }
                let controller = window.windowController as? MainWindowController
                button.isEnabled = controller != nil
                button.controlsCollapsed = controller?.isControlAreaCollapsed ?? false
                let label = button.controlsCollapsed ? "展开控制区域" : "收起控制区域"
                button.updateControlAreaHelp(controller == nil ? nil : label)
                button.setAccessibilityLabel(label)
                button.setAccessibilityExpanded(!button.controlsCollapsed)
            }
            button.needsDisplay = true
        }
    }

    private var hoverRect: NSRect { bounds.intersection(visibleRect) }

    private func updateHoverState() {
        guard let window, window.isVisible else {
            setHovering(false)
            return
        }
        let position = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        setHovering(!isHiddenOrHasHiddenAncestor && hoverRect.contains(position))
    }

    private func setHovering(_ hovering: Bool) {
        buttons.forEach { $0.showsSymbols = hovering }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AquaWindowButtonGroup uses programmatic initialization.")
    }
}
