import AppKit

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let chrome = SettingsChromeView()
    private var shadowWindow: TigerWindowShadow?
    private let settings: AppSettings
    private let panes: [SettingsPaneViewController]
    private var resizeAnimation: Timer?
    private var targetPaneHeight: CGFloat = 240
    private var visiblePaneHeight: CGFloat = 240
    private(set) var isToolbarVisible = true

    init(settings: AppSettings = .shared) {
        self.settings = settings
        panes = [GeneralSettingsViewController(settings: settings), ReminderSettingsViewController(settings: settings)]
        let window = SettingsWindow(contentRect: NSRect(x: 0, y: 0, width: SettingsLayout.width, height: 330),
                                    styleMask: [.borderless, .closable], backing: .buffered, defer: false)
        super.init(window: window)
        window.title = "偏好设置"
        window.setAccessibilityIdentifier("Settings.Window")
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenNone, .fullScreenDisallowsTiling]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.animationBehavior = .none
        window.isMovableByWindowBackground = false
        window.contentView = chrome
        chrome.selectPane = { [weak self] in self?.selectPane(at: $0) }
        chrome.toolbarToggle.target = window
        chrome.toolbarToggle.action = #selector(SettingsWindow.toggleSettingsToolbar(_:))
        window.delegate = self
        selectPane(at: settings.selectedPane)
        window.center()
    }

    override func showWindow(_ sender: Any?) {
        guard let window else { return }
        let opening = !window.isVisible
        panes[settings.selectedPane].prepareForPresentation()
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        if shadowWindow == nil { shadowWindow = TigerWindowShadow(owner: window, shape: .standardAqua) }
        updateShadow()
        super.showWindow(sender)
        if let shadowWindow {
            if shadowWindow.parent !== window { window.addChildWindow(shadowWindow, ordered: .below) }
            shadowWindow.order(.below, relativeTo: window.windowNumber)
        }
        window.makeKeyAndOrderFront(sender)
        if opening { window.makeFirstResponder(nil) }
    }

    private func selectPane(at index: Int) {
        window?.makeFirstResponder(nil)
        settings.selectedPane = index
        let pane = panes[index]
        pane.prepareForPresentation()
        targetPaneHeight = max(240, ceil(pane.view.fittingSize.height))
        let title = index == 0 ? "常规" : "提醒"
        chrome.present(pane.view, height: targetPaneHeight, at: index, title: title)
        window?.title = title
        window?.recalculateKeyViewLoop()
        animatePresentation(duration: 0.22)
    }

    func toggleToolbar() {
        guard let window else { return }
        isToolbarVisible.toggle()
        chrome.toolbarToggle.isToolbarVisible = isToolbarVisible
        if !isToolbarVisible, chrome.toolbarHasKeyboardFocus(in: window) {
            window.makeFirstResponder(chrome.toolbarToggle)
        }
        chrome.setPaneButtonsEnabled(false)
        let distance = abs(targetToolbarHeight - chrome.visibleToolbarHeight)
        animatePresentation(duration: max(0.06, 0.22 * Double(distance / SettingsChromeView.toolbarHeight)))
    }

    private var targetToolbarHeight: CGFloat { isToolbarVisible ? SettingsChromeView.toolbarHeight : 0 }

    private func animatePresentation(duration: TimeInterval) {
        resizeAnimation?.invalidate()
        resizeAnimation = nil

        let initialToolbarHeight = chrome.visibleToolbarHeight
        let initialPaneHeight = visiblePaneHeight
        let toolbarHeight = targetToolbarHeight
        let paneHeight = targetPaneHeight
        guard let window, window.isVisible,
              initialToolbarHeight != toolbarHeight || initialPaneHeight != paneHeight,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            finishPresentation()
            return
        }

        let start = ProcessInfo.processInfo.systemUptime
        let backingScale = max(1, window.backingScaleFactor)
        // Both transitions start from the current geometry, including when interrupted.
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            MainActor.assumeIsolated {
                let progress = min(1, (ProcessInfo.processInfo.systemUptime - start) / duration)
                if progress == 1 {
                    self.finishPresentation()
                } else {
                    let eased = CGFloat(progress * progress * (3 - 2 * progress))
                    let toolbar = initialToolbarHeight + (toolbarHeight - initialToolbarHeight) * eased
                    let pane = initialPaneHeight + (paneHeight - initialPaneHeight) * eased
                    self.resizePresentation(toolbarHeight: (toolbar * backingScale).rounded() / backingScale,
                                            paneHeight: (pane * backingScale).rounded() / backingScale)
                }
            }
        }
        resizeAnimation = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func resizePresentation(toolbarHeight: CGFloat, paneHeight: CGFloat) {
        chrome.visibleToolbarHeight = toolbarHeight
        visiblePaneHeight = paneHeight
        (window as? SettingsWindow)?.fitContent(NSSize(width: SettingsLayout.width,
                                                       height: paneHeight + chrome.headerHeight))
        chrome.layoutSubtreeIfNeeded()
    }

    private func finishPresentation() {
        resizeAnimation?.invalidate()
        resizeAnimation = nil
        resizePresentation(toolbarHeight: targetToolbarHeight, paneHeight: targetPaneHeight)
        chrome.setPaneButtonsEnabled(isToolbarVisible)
        window?.recalculateKeyViewLoop()
        updateShadow()
    }

    func windowWillClose(_ notification: Notification) {
        if resizeAnimation != nil { finishPresentation() }
        window?.makeFirstResponder(nil)
        CompletionSoundPlayer.shared.stopPreview()
        shadowWindow?.orderOut(nil)
    }

    func windowDidMove(_ notification: Notification) { updateShadow() }
    func windowDidResize(_ notification: Notification) { updateShadow() }
    func windowDidBecomeKey(_ notification: Notification) { updateShadow() }
    func windowDidResignKey(_ notification: Notification) { updateShadow() }

    private func updateShadow() {
        if let window { shadowWindow?.synchronize(with: window) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("SettingsWindowController uses programmatic initialization.") }
}

@MainActor
final class SettingsWindow: NSWindow {
    private let textHistory = UndoManager()
    private var fixedSize: NSSize?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override var undoManager: UndoManager? { textHistory }

    // Presentation changes preserve the titlebar's screen position.
    func fitContent(_ size: NSSize) {
        guard fixedSize != size else { return }
        let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
        fixedSize = size
        contentMaxSize = NSSize(width: max(contentMaxSize.width, size.width),
                                height: max(contentMaxSize.height, size.height))
        contentMinSize = size
        contentMaxSize = size
        super.setFrame(NSRect(x: topLeft.x, y: topLeft.y - size.height,
                              width: size.width, height: size.height), display: true)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(constrainedFrame(frameRect), display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate animateFlag: Bool) {
        super.setFrame(constrainedFrame(frameRect), display: flag, animate: animateFlag)
    }

    private func constrainedFrame(_ requested: NSRect) -> NSRect {
        guard let fixedSize, requested.size != fixedSize else { return requested }
        return NSRect(origin: frame.origin, size: fixedSize)
    }

    private var activeTextUndo: UndoManager? {
        guard let editor = firstResponder as? NSTextView, editor.isFieldEditor else { return nil }
        return editor.undoManager
    }

    // The app's Edit menu routes duration undo explicitly. Intercept those
    // commands here so editing settings never undoes the timer behind this window.
    @objc func undoDurationEdit(_ sender: Any?) { activeTextUndo?.undo() }
    @objc func redoDurationEdit(_ sender: Any?) { activeTextUndo?.redo() }
    override func performClose(_ sender: Any?) { close() }
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
    override func toggleFullScreen(_ sender: Any?) {}
    override func zoom(_ sender: Any?) {}
    override func performZoom(_ sender: Any?) {}

    @objc func toggleSettingsToolbar(_ sender: Any?) {
        (windowController as? SettingsWindowController)?.toggleToolbar()
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(toggleSettingsToolbar(_:)):
            guard let controller = windowController as? SettingsWindowController else { return false }
            menuItem.title = controller.isToolbarVisible ? "隐藏工具栏" : "显示工具栏"
            return true
        case #selector(performClose(_:)): return true
        case #selector(undoDurationEdit(_:)): return activeTextUndo?.canUndo == true
        case #selector(redoDurationEdit(_:)): return activeTextUndo?.canRedo == true
        case #selector(performMiniaturize(_:)), #selector(toggleFullScreen(_:)),
             #selector(zoom(_:)), #selector(performZoom(_:)): return false
        default: return super.validateMenuItem(menuItem)
        }
    }
}

/// Standard Aqua shell with a toolbar that switches between settings panes.
@MainActor
private final class SettingsChromeView: TigerAquaBackgroundView {
    static let toolbarHeight: CGFloat = 62
    var headerHeight: CGFloat { Self.titlebarHeight + visibleToolbarHeight }
    var visibleToolbarHeight = toolbarHeight {
        didSet {
            guard oldValue != visibleToolbarHeight else { return }
            toolbarHeightConstraint.constant = visibleToolbarHeight
            toolbarClip.isHidden = visibleToolbarHeight == 0
            needsDisplay = true
        }
    }
    var selectPane: ((Int) -> Void)?
    let toolbarToggle = SettingsToolbarToggle()
    private let titlebar = WindowTitlebarView(purpose: .settings)
    private let paneHost = NSView()
    private let toolbarClip = NSView()
    private lazy var toolbarHeightConstraint = toolbarClip.heightAnchor.constraint(equalToConstant: Self.toolbarHeight)
    private var paneButtons: [SettingsPaneButton] = []

    init() {
        super.init(frame: .zero)
        setAccessibilityIdentifier("Settings.Chrome")
        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 4
        toolbar.setAccessibilityRole(.toolbar)
        toolbar.setAccessibilityLabel("偏好设置分类")
        toolbar.setAccessibilityIdentifier("Settings.Toolbar")
        let general = NSImage(named: NSImage.preferencesGeneralName)
            ?? NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        let reminders = NSImage(named: NSImage.Name("AquaSettingsSpeaker"))
            ?? NSImage(systemSymbolName: "speaker.wave.2", accessibilityDescription: nil)
        let items = [("常规", "Settings.General", general), ("提醒", "Settings.Reminders", reminders)]
        for (index, item) in items.enumerated() {
            let (title, identifier, artwork) = item
            let button = SettingsPaneButton(title: title, artwork: artwork)
            button.target = self
            button.action = #selector(changePane(_:))
            button.tag = index
            button.setAccessibilityIdentifier(identifier)
            toolbar.addArrangedSubview(button)
            paneButtons.append(button)
        }
        let focus = AquaFocusRingOverlay(frame: .zero)
        toolbarClip.clipsToBounds = true
        paneHost.clipsToBounds = true
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbarClip.addSubview(toolbar)
        toolbarToggle.translatesAutoresizingMaskIntoConstraints = false
        titlebar.addSubview(toolbarToggle)
        [titlebar, toolbarClip, paneHost, focus].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            titlebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            titlebar.trailingAnchor.constraint(equalTo: trailingAnchor),
            titlebar.topAnchor.constraint(equalTo: topAnchor),
            titlebar.heightAnchor.constraint(equalToConstant: Self.titlebarHeight),
            toolbarToggle.trailingAnchor.constraint(equalTo: titlebar.trailingAnchor, constant: -6),
            toolbarToggle.centerYAnchor.constraint(equalTo: titlebar.centerYAnchor),
            toolbarClip.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbarClip.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbarClip.topAnchor.constraint(equalTo: titlebar.bottomAnchor),
            toolbarHeightConstraint,
            toolbar.leadingAnchor.constraint(equalTo: toolbarClip.leadingAnchor, constant: 10),
            toolbar.topAnchor.constraint(equalTo: toolbarClip.topAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: Self.toolbarHeight),
            paneHost.leadingAnchor.constraint(equalTo: leadingAnchor),
            paneHost.trailingAnchor.constraint(equalTo: trailingAnchor),
            paneHost.topAnchor.constraint(equalTo: toolbarClip.bottomAnchor),
            paneHost.bottomAnchor.constraint(equalTo: bottomAnchor),
            focus.leadingAnchor.constraint(equalTo: leadingAnchor),
            focus.trailingAnchor.constraint(equalTo: trailingAnchor),
            focus.topAnchor.constraint(equalTo: topAnchor),
            focus.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func present(_ pane: NSView, height: CGFloat, at index: Int, title: String) {
        paneHost.subviews.forEach { $0.removeFromSuperview() }
        pane.translatesAutoresizingMaskIntoConstraints = false
        paneHost.addSubview(pane)
        NSLayoutConstraint.activate([
            pane.leadingAnchor.constraint(equalTo: paneHost.leadingAnchor),
            pane.trailingAnchor.constraint(equalTo: paneHost.trailingAnchor),
            pane.topAnchor.constraint(equalTo: paneHost.topAnchor),
            // Keep the form at its fitted height while the host reveals or clips it.
            pane.heightAnchor.constraint(equalToConstant: height)
        ])
        titlebar.updateTitle(title)
        for button in paneButtons {
            button.state = button.tag == index ? .on : .off
        }
    }

    func toolbarHasKeyboardFocus(in window: NSWindow) -> Bool {
        paneButtons.contains { $0 === window.firstResponder }
    }

    func setPaneButtonsEnabled(_ enabled: Bool) {
        paneButtons.forEach { $0.isEnabled = enabled }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard visibleToolbarHeight >= 1 else { return }
        // The HIG preferences toolbar is a lighter striped band above the form.
        // Keep the same stripe phase and leave the window outline untouched.
        let toolbar = NSRect(x: 0.5, y: Self.titlebarHeight,
                             width: bounds.width - 1, height: visibleToolbarHeight - 1)
        NSColor(srgbRed: 245.0 / 255, green: 245.0 / 255, blue: 245.0 / 255, alpha: 1).setFill()
        toolbar.fill()
        NSColor(srgbRed: 240.0 / 255, green: 240.0 / 255, blue: 240.0 / 255, alpha: 1).setFill()
        for y in stride(from: toolbar.minY, to: toolbar.maxY, by: 2) {
            NSRect(x: toolbar.minX, y: y, width: toolbar.width, height: min(1, toolbar.maxY - y)).fill()
        }
        NSColor(calibratedWhite: 0.68, alpha: 1).setFill()
        NSRect(x: 1, y: headerHeight - 1, width: bounds.width - 2, height: 0.5).fill()
        NSColor.white.withAlphaComponent(0.75).setFill()
        NSRect(x: 1, y: headerHeight - 0.5, width: bounds.width - 2, height: 0.5).fill()
    }

    @objc private func changePane(_ sender: NSButton) { selectPane?(sender.tag) }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("SettingsChromeView uses programmatic initialization.") }
}

/// Retains NSButton selection and activation while presenting untinted toolbar art.
@MainActor
private final class SettingsPaneButton: NSButton, AquaFocusTarget {
    private let artwork: NSImage?
    private static let iconSize: CGFloat = 32

    init(title: String, artwork: NSImage?) {
        self.artwork = artwork
        super.init(frame: .zero)
        self.title = title
        setButtonType(.pushOnPushOff)
        isBordered = false
        focusRingType = .none
        setAccessibilityLabel(title)
    }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: 64, height: SettingsChromeView.toolbarHeight) }
    override var state: NSControl.StateValue { didSet { needsDisplay = true } }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    var aquaFocusGeometry: AquaFocusGeometry {
        AquaFocusGeometry(rect: bounds.insetBy(dx: 4, dy: 4), shape: .roundedRect(2))
    }

    override func draw(_ dirtyRect: NSRect) {
        if state == .on || isHighlighted {
            drawSelection()
        }
        let iconRect = NSRect(x: bounds.midX - Self.iconSize / 2, y: bounds.minY + 7,
                              width: Self.iconSize, height: Self.iconSize)
        artwork?.draw(in: iconRect, from: .zero, operation: .sourceOver,
                      fraction: 1, respectFlipped: true, hints: nil)
        let caption = NSAttributedString(string: title, attributes: [
            .font: AquaTypography.font(ofSize: 11),
            .foregroundColor: AquaTypography.secondaryInk
        ])
        caption.draw(at: NSPoint(x: bounds.midX - caption.size().width / 2,
                                 y: iconRect.maxY + 3))
    }

    private func drawSelection() {
        // Tint the stripes in place, leaving the toolbar's bottom divider visible.
        let selection = NSRect(x: bounds.minX, y: bounds.minY,
                               width: bounds.width, height: bounds.height - 1)
        NSColor.black.withAlphaComponent(isHighlighted ? 0.15 : 0.105).setFill()
        selection.insetBy(dx: 1, dy: 0).fill()
        NSColor.black.withAlphaComponent(isHighlighted ? 0.30 : 0.25).setFill()
        NSRect(x: selection.minX, y: selection.minY, width: 1, height: selection.height).fill()
        NSRect(x: selection.maxX - 1, y: selection.minY, width: 1, height: selection.height).fill()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("SettingsPaneButton uses programmatic initialization.") }
}
