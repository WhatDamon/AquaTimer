import AppKit

@MainActor
final class MainWindowController: NSWindowController, NSWindowDelegate {
    static let controlAreaDidChangeNotification = Notification.Name("AquaTimer.ControlAreaDidChange")
    private static let geometryKey = "AquaTimer.MainWindow.CompactLayout.ExpandedFrame"
    private static let previousGeometryKey = "AquaTimer.MainWindow.ExpandedFrame"
    private let timerController = TimerViewController()
    private var expandedSize = NSSize(width: 380, height: 392)
    private var isChangingFrame = false
    private var shadowWindow: TigerWindowShadow?
    private(set) var isControlAreaCollapsed = false

    init() {
        let window = AquaWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 400),
            styleMask: [.borderless, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "AquaTimer"
        window.isOpaque = false
        window.backgroundColor = .clear
        if #available(macOS 26.0, *) {
            // Keep the transparent shell and its separate shadow out of the automatic open/close transition.
            window.animationBehavior = .none
        }
        window.hasShadow = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.fullScreenNone, .fullScreenDisallowsTiling]
        window.contentViewController = WindowContentViewController(content: timerController)
        window.initialFirstResponder = timerController.preferredFirstResponder(controlsCollapsed: false)
        window.contentView?.layoutSubtreeIfNeeded()
        expandedSize.height = ceil(WindowContentViewController.titlebarHeight + timerController.expandedHeight)
        window.setPresentationSize(expandedSize, display: false, animate: false)
        window.isReleasedWhenClosed = false
        isControlAreaCollapsed = AppSettings.shared.initialControlsCollapsed
        AppSettings.shared.rememberControlsCollapsed(isControlAreaCollapsed)
        timerController.setControlsCollapsed(isControlAreaCollapsed)
        if isControlAreaCollapsed {
            window.setPresentationSize(NSSize(width: expandedSize.width, height: compactHeight), display: false, animate: false)
        }
        window.center()
        // Restore placement only while user resizing is disabled.
        let saved = UserDefaults.standard.string(forKey: Self.geometryKey)
            ?? UserDefaults.standard.string(forKey: Self.previousGeometryKey)
        if let saved {
            let previousFrame = NSRectFromString(saved)
            if previousFrame.origin.x.isFinite, previousFrame.origin.y.isFinite,
               previousFrame.width.isFinite, previousFrame.height.isFinite,
               previousFrame.width > 0, previousFrame.height > 0 {
                var frame = window.frame
                frame.origin = NSPoint(x: previousFrame.midX - frame.width / 2,
                                       y: previousFrame.maxY - frame.height)
                window.setFrame(frame, display: false)
            }
        }
        updateMetalLightingHeight()
        window.delegate = self
        window.initialFirstResponder = timerController.preferredFirstResponder(controlsCollapsed: isControlAreaCollapsed)
        window.contentView?.layoutSubtreeIfNeeded()
        window.invalidateShadow()
        notifyPresentationChanged()
    }

    override func showWindow(_ sender: Any?) {
        guard let window else {
            super.showWindow(sender)
            return
        }
        let needsInitialFocus = !window.isVisible
        if needsInitialFocus {
            window.initialFirstResponder = timerController.preferredFirstResponder(
                controlsCollapsed: isControlAreaCollapsed
            )
        }

        // Complete layout and backing-store drawing before AppKit orders either surface onto the screen.
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        if shadowWindow == nil { shadowWindow = TigerWindowShadow(owner: window) }
        if let shadowWindow {
            shadowWindow.synchronize(with: window)
            shadowWindow.contentView?.layoutSubtreeIfNeeded()
            shadowWindow.displayIfNeeded()
        }

        super.showWindow(sender)
        if let shadowWindow {
            if shadowWindow.parent !== window { window.addChildWindow(shadowWindow, ordered: .below) }
            shadowWindow.order(.below, relativeTo: window.windowNumber)
        }
        if needsInitialFocus { timerController.focusControls(controlsCollapsed: isControlAreaCollapsed) }
    }

    private func updateWindowShadow() {
        guard let window else { return }
        shadowWindow?.synchronize(with: window)
    }

    private var compactHeight: CGFloat {
        window?.contentView?.layoutSubtreeIfNeeded()
        return ceil(WindowContentViewController.titlebarHeight + timerController.compactHeight)
    }

    func toggleControlArea() {
        guard let window = window as? AquaWindow, !isChangingFrame else { return }
        if !isControlAreaCollapsed && !timerController.prepareToCollapse() { return }
        let collapsing = !isControlAreaCollapsed
        // Keep the metal lighting and grain anchored to the expanded surface throughout resizing.
        updateMetalLightingHeight()
        isControlAreaCollapsed = collapsing
        isChangingFrame = true
        // Remove controls before shrinking; attach them only after there is room again.
        if collapsing { timerController.setControlsCollapsed(true) }
        let size = NSSize(width: expandedSize.width,
                          height: collapsing ? compactHeight : expandedSize.height)
        window.setPresentationSize(size, display: true,
                                   animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        if !collapsing { timerController.setControlsCollapsed(false) }
        window.contentView?.layoutSubtreeIfNeeded()
        window.invalidateShadow()
        isChangingFrame = false
        AppSettings.shared.rememberControlsCollapsed(isControlAreaCollapsed)
        saveExpandedGeometry()
        notifyPresentationChanged()
    }

    private func updateMetalLightingHeight() {
        (window?.contentViewController as? WindowContentViewController)?.setMetalLightingHeight(expandedSize.height)
    }

    private func notifyPresentationChanged() {
        guard let window else { return }
        NotificationCenter.default.post(name: Self.controlAreaDidChangeNotification, object: window)
    }

    private func saveExpandedGeometry() {
        guard let window, !isChangingFrame else { return }
        var normalFrame = window.frame
        normalFrame.origin.y = normalFrame.maxY - expandedSize.height
        normalFrame.size = expandedSize
        UserDefaults.standard.set(NSStringFromRect(normalFrame), forKey: Self.geometryKey)
    }

    func windowDidMove(_ notification: Notification) {
        updateWindowShadow()
        saveExpandedGeometry()
    }
    func windowDidResize(_ notification: Notification) {
        updateWindowShadow()
        saveExpandedGeometry()
    }
    func windowDidBecomeKey(_ notification: Notification) { updateWindowShadow() }
    func windowDidResignKey(_ notification: Notification) { updateWindowShadow() }
    func windowWillClose(_ notification: Notification) {
        shadowWindow?.orderOut(nil)
        saveExpandedGeometry()
    }

    var primaryActionTitle: String { timerController.primaryActionTitle }
    var canPerformPrimaryAction: Bool { timerController.canPerformPrimaryAction }
    var canResetTimer: Bool { timerController.canResetTimer }
    var hasActiveCountdown: Bool { timerController.hasActiveCountdown }
    var canStopTimerAlert: Bool { timerController.canStopTimerAlert }
    func stopTimerAlert() { timerController.stopTimerAlert() }
    func performPrimaryAction(_ sender: Any?) { timerController.performPrimaryAction(sender) }
    func resetTimer(_ sender: Any?) { timerController.resetTimer(sender) }
    var canUndoDurationEdit: Bool { timerController.canUndoDurationEdit }
    var canRedoDurationEdit: Bool { timerController.canRedoDurationEdit }
    func undoDurationEdit() { timerController.undoDurationEdit() }
    func redoDurationEdit() { timerController.redoDurationEdit() }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MainWindowController uses programmatic initialization.")
    }
}
