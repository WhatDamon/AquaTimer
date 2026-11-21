import AppKit

/// A modeless About window based on Figure 13-27 of the December 2005 HIG.
@MainActor
final class AboutWindowController: NSWindowController, NSWindowDelegate {
    private var shadowWindow: TigerWindowShadow?

    init() {
        let content = AboutContentView()
        let size = NSSize(width: 320, height: content.requiredHeight)
        let panel = AboutPanel(contentRect: NSRect(origin: .zero, size: size),
                               styleMask: [.borderless, .closable], backing: .buffered, defer: false)
        super.init(window: panel)
        // Keep the accessible/window-menu name, while the historical chrome has no title text.
        panel.title = "关于 AquaTimer"
        panel.setAccessibilityIdentifier("About.Window")
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isFloatingPanel = false
        panel.hidesOnDeactivate = false
        panel.level = .normal
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.fullScreenNone, .fullScreenDisallowsTiling]
        panel.animationBehavior = .none
        panel.contentView = content
        panel.lockSize(size)
        panel.delegate = self
        panel.center()
    }

    override func showWindow(_ sender: Any?) {
        guard let window else { return }
        let opening = !window.isVisible
        window.contentView?.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        if shadowWindow == nil { shadowWindow = TigerWindowShadow(owner: window, shape: .standardAqua) }
        shadowWindow?.synchronize(with: window)
        super.showWindow(sender)
        if let shadowWindow {
            if shadowWindow.parent !== window { window.addChildWindow(shadowWindow, ordered: .below) }
            shadowWindow.order(.below, relativeTo: window.windowNumber)
        }
        window.makeKeyAndOrderFront(sender)
        if opening { window.makeFirstResponder(nil) }
    }

    func windowDidMove(_ notification: Notification) { updateShadow() }
    func windowDidBecomeKey(_ notification: Notification) { updateShadow() }
    func windowDidResignKey(_ notification: Notification) { updateShadow() }
    func windowWillClose(_ notification: Notification) { shadowWindow?.orderOut(nil) }

    private func updateShadow() {
        if let window { shadowWindow?.synchronize(with: window) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("AboutWindowController uses programmatic initialization.") }
}

@MainActor
private final class AboutPanel: NSPanel {
    private var fixedSize: NSSize?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func lockSize(_ size: NSSize) {
        fixedSize = size
        contentMinSize = size
        contentMaxSize = size
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

    override func performClose(_ sender: Any?) { close() }
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
    override func toggleFullScreen(_ sender: Any?) {}
    override func zoom(_ sender: Any?) {}
    override func performZoom(_ sender: Any?) {}

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(performClose(_:)): return true
        case #selector(performMiniaturize(_:)), #selector(toggleFullScreen(_:)),
             #selector(zoom(_:)), #selector(performZoom(_:)): return false
        default: return super.validateMenuItem(menuItem)
        }
    }
}

@MainActor
private final class AboutContentView: TigerAquaBackgroundView {
    private let content = NSStackView()
    var requiredHeight: CGFloat {
        ceil(Self.titlebarHeight + 16 + content.fittingSize.height + 20)
    }

    init() {
        super.init(frame: .zero)
        let titlebar = WindowTitlebarView(purpose: .about)
        let icon = NSImageView()
        // Read the compiled file so a stale Dock/application-icon cache cannot show a placeholder.
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns") {
            icon.image = NSImage(contentsOf: url)
        }
        if icon.image == nil { icon.image = NSApp.applicationIconImage }
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityElement(false)
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true

        let info = Bundle.main.infoDictionary ?? [:]
        let name = label("AquaTimer", size: 14, emphasized: true)
        let version = info["CFBundleShortVersionString"] as? String ?? "—"
        let build = info["CFBundleVersion"] as? String
        let versionText = label("版本 \(version)" + (build.map { "（\($0)）" } ?? ""), size: 10)
        versionText.setAccessibilityIdentifier("About.Version")
        let description = label("为现代 macOS 打造的桌面计时器。\n以 Tiger 时代的 Aqua 界面为灵感。", size: 11, alignment: .left)
        let credits = label("DSEG7 Classic 字体 © 2017 keshikan\nSIL Open Font License 1.1", size: 10, alignment: .left)
        credits.textColor = AquaTypography.secondaryInk

        content.orientation = .vertical
        content.alignment = .centerX
        content.spacing = 4
        [icon, name, versionText, description, credits].forEach { content.addArrangedSubview($0) }
        content.setCustomSpacing(8, after: icon)
        content.setCustomSpacing(14, after: versionText)
        content.setCustomSpacing(12, after: description)
        if let copyright = info["NSHumanReadableCopyright"] as? String, !copyright.isEmpty {
            content.addArrangedSubview(label(copyright, size: 10, alignment: .left))
        }
        let focus = AquaFocusRingOverlay(frame: .zero)
        [titlebar, content, focus].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }
        NSLayoutConstraint.activate([
            titlebar.leadingAnchor.constraint(equalTo: leadingAnchor),
            titlebar.trailingAnchor.constraint(equalTo: trailingAnchor),
            titlebar.topAnchor.constraint(equalTo: topAnchor),
            titlebar.heightAnchor.constraint(equalToConstant: Self.titlebarHeight),
            content.topAnchor.constraint(equalTo: titlebar.bottomAnchor, constant: 16),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.widthAnchor.constraint(equalToConstant: 264),
            focus.leadingAnchor.constraint(equalTo: leadingAnchor),
            focus.trailingAnchor.constraint(equalTo: trailingAnchor),
            focus.topAnchor.constraint(equalTo: topAnchor),
            focus.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func label(_ text: String, size: CGFloat, emphasized: Bool = false,
                       alignment: NSTextAlignment = .center) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = AquaTypography.font(ofSize: size, emphasized: emphasized)
        label.textColor = NSColor(calibratedWhite: 0.12, alpha: 1)
        label.alignment = alignment
        label.widthAnchor.constraint(equalToConstant: 264).isActive = true
        return label
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("AboutContentView uses programmatic initialization.") }
}
