import AppKit

@MainActor
final class AquaWindow: NSWindow {
    private var fixedFrameSize: NSSize?
    private var isUpdatingPresentation = false

    /// Only the timer's presentation action can change the locked window size.
    func setPresentationSize(_ contentSize: NSSize, display: Bool, animate: Bool) {
        let targetSize = frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
        var target = frame
        target.origin.y = target.maxY - targetSize.height
        target.size = targetSize
        isUpdatingPresentation = true
        defer { isUpdatingPresentation = false }
        contentMaxSize = NSSize(width: max(contentMaxSize.width, contentSize.width),
                                height: max(contentMaxSize.height, contentSize.height))
        contentMinSize = contentSize
        contentMaxSize = contentSize
        fixedFrameSize = targetSize
        super.setFrame(target, display: display, animate: animate)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(constrainedFrame(frameRect), display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        super.setFrame(constrainedFrame(frameRect), display: flag, animate: animateFlag)
    }

    private func constrainedFrame(_ requested: NSRect) -> NSRect {
        guard !isUpdatingPresentation, let fixedFrameSize,
              requested.size != fixedFrameSize else { return requested }
        // Some system sizing actions call setFrame directly and bypass min/max constraints.
        return NSRect(origin: frame.origin, size: fixedFrameSize)
    }

    override func zoom(_ sender: Any?) {}
    override func performZoom(_ sender: Any?) {}

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override var title: String {
        didSet {
            (contentViewController as? WindowContentViewController)?.updateTitle(title)
        }
    }

    override func performClose(_ sender: Any?) {
        guard styleMask.contains(.closable), delegate?.windowShouldClose?(self) != false else { return }
        // A borderless window has no standard close button for performClose to activate.
        close()
    }

    override func performMiniaturize(_ sender: Any?) {
        guard styleMask.contains(.miniaturizable) else { return }
        miniaturize(sender)
    }

    override func animationResizeTime(_ newFrame: NSRect) -> TimeInterval { 0.2 }

    // Block system full-screen actions, including Fn-F, independently of menu availability.
    override func toggleFullScreen(_ sender: Any?) {}

    @objc func toggleControlArea(_ sender: Any?) {
        (windowController as? MainWindowController)?.toggleControlArea()
    }

    @objc func performTimerPrimaryAction(_ sender: Any?) {
        (windowController as? MainWindowController)?.performPrimaryAction(sender)
    }

    @objc func resetTimer(_ sender: Any?) {
        (windowController as? MainWindowController)?.resetTimer(sender)
    }

    @objc func undoDurationEdit(_ sender: Any?) {
        (windowController as? MainWindowController)?.undoDurationEdit()
    }

    @objc func redoDurationEdit(_ sender: Any?) {
        (windowController as? MainWindowController)?.redoDurationEdit()
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let controller = windowController as? MainWindowController else {
            return super.validateMenuItem(menuItem)
        }
        switch menuItem.action {
        case #selector(undoDurationEdit(_:)):
            return controller.canUndoDurationEdit
        case #selector(redoDurationEdit(_:)):
            return controller.canRedoDurationEdit
        case #selector(toggleControlArea(_:)):
            menuItem.title = controller.isControlAreaCollapsed ? "展开控制区域" : "收起控制区域"
            return true
        case #selector(performTimerPrimaryAction(_:)):
            menuItem.title = controller.primaryActionTitle
            return controller.canPerformPrimaryAction
        case #selector(resetTimer(_:)):
            return controller.canResetTimer
        case #selector(performClose(_:)):
            return styleMask.contains(.closable)
        case #selector(performMiniaturize(_:)):
            return styleMask.contains(.miniaturizable) && !isMiniaturized
        case #selector(toggleFullScreen(_:)), #selector(performZoom(_:)), #selector(zoom(_:)):
            return false
        default:
            return super.validateMenuItem(menuItem)
        }
    }
}
