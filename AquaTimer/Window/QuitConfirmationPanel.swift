import AppKit

/// App-wide quit confirmation with the alert layout from the 2005 Apple HIG.
@MainActor
final class QuitConfirmationPanel: NSPanel {
    private let surface = QuitAlertSurface()
    private let cancelButton = AquaPushButton(label: "取消", isDefaultAction: true)
    private let quitButton = AquaPushButton(label: "退出")

    init() {
        let size = NSSize(width: 426, height: 162)
        super.init(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless],
                   backing: .buffered, defer: false)
        title = "退出 AquaTimer"
        setAccessibilityIdentifier("QuitConfirmation.Window")
        setAccessibilitySubrole(.dialog)
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        animationBehavior = .none
        level = .modalPanel
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        contentView = surface

        let message = NSTextField(wrappingLabelWithString: "计时尚未结束。要退出 AquaTimer 吗？")
        message.preferredMaxLayoutWidth = size.width - 128
        message.font = AquaTypography.font(ofSize: 13, emphasized: true)
        message.textColor = AquaGlassMaterial.color(0x202226)
        let explanation = NSTextField(wrappingLabelWithString:
            "退出后，本次倒计时会停止。想让计时继续，可以取消退出，再关闭主窗口。")
        explanation.preferredMaxLayoutWidth = message.preferredMaxLayoutWidth
        explanation.font = AquaTypography.font(ofSize: 12)
        explanation.textColor = AquaTypography.secondaryInk
        let caution = Self.alertIcon()

        cancelButton.target = self
        cancelButton.action = #selector(keepRunning(_:))
        cancelButton.keyEquivalent = "\r"
        cancelButton.setAccessibilityIdentifier("QuitConfirmation.Cancel")
        quitButton.target = self
        quitButton.action = #selector(quit(_:))
        quitButton.setAccessibilityIdentifier("QuitConfirmation.Quit")

        let buttons = NSStackView(views: [cancelButton, quitButton])
        buttons.spacing = 12
        let focus = AquaFocusRingOverlay(frame: .zero)
        [caution, message, explanation, buttons, focus].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            surface.addSubview($0)
        }
        NSLayoutConstraint.activate([
            caution.leadingAnchor.constraint(equalTo: surface.leadingAnchor, constant: 24),
            caution.topAnchor.constraint(equalTo: surface.topAnchor, constant: 37),
            caution.widthAnchor.constraint(equalToConstant: 64),
            caution.heightAnchor.constraint(equalToConstant: 64),
            message.leadingAnchor.constraint(equalTo: caution.trailingAnchor, constant: 16),
            message.trailingAnchor.constraint(equalTo: surface.trailingAnchor, constant: -24),
            message.topAnchor.constraint(equalTo: caution.topAnchor),
            explanation.leadingAnchor.constraint(equalTo: message.leadingAnchor),
            explanation.trailingAnchor.constraint(equalTo: message.trailingAnchor),
            explanation.topAnchor.constraint(equalTo: message.bottomAnchor, constant: 8),
            buttons.trailingAnchor.constraint(equalTo: message.trailingAnchor),
            buttons.topAnchor.constraint(equalTo: explanation.bottomAnchor, constant: 10),
            buttons.bottomAnchor.constraint(equalTo: surface.bottomAnchor, constant: -14),
            focus.leadingAnchor.constraint(equalTo: surface.leadingAnchor),
            focus.trailingAnchor.constraint(equalTo: surface.trailingAnchor),
            focus.topAnchor.constraint(equalTo: surface.topAnchor),
            focus.bottomAnchor.constraint(equalTo: surface.bottomAnchor)
        ])
        setContentSize(NSSize(width: size.width, height: ceil(surface.fittingSize.height)))
        defaultButtonCell = cancelButton.cell as? NSButtonCell
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func confirm(in application: NSApplication) -> Bool {
        center()
        surface.layoutSubtreeIfNeeded()
        let shadow = TigerWindowShadow(owner: self, shape: .standardAqua)
        makeKeyAndOrderFront(nil)
        addChildWindow(shadow, ordered: .below)
        shadow.synchronize(with: self)
        let pulse = startDefaultButtonPulse()
        let response = application.runModal(for: self)
        pulse.invalidate()
        cancelButton.defaultPulseAmount = 0
        removeChildWindow(shadow)
        shadow.orderOut(nil)
        orderOut(nil)
        return response == .OK
    }

    private func startDefaultButtonPulse() -> Timer {
        let start = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            MainActor.assumeIsolated {
                guard self.isKeyWindow, NSApp.isActive,
                      !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
                    self.cancelButton.defaultPulseAmount = 0
                    return
                }
                let elapsed = ProcessInfo.processInfo.systemUptime - start
                // A full cycle starts and ends with the original blue.
                self.cancelButton.defaultPulseAmount = CGFloat((1 - cos(elapsed * 2 * .pi / 2.4)) / 2)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        // runModal can run in its own mode while the alert is waiting for a response.
        RunLoop.main.add(timer, forMode: .modalPanel)
        return timer
    }

    override func cancelOperation(_ sender: Any?) { keepRunning(sender) }
    override func performClose(_ sender: Any?) { keepRunning(sender) }

    @objc private func keepRunning(_ sender: Any?) { NSApp.stopModal(withCode: .cancel) }
    @objc private func quit(_ sender: Any?) { NSApp.stopModal(withCode: .OK) }

    private static func alertIcon() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 64, height: 64))
        let caution = NSImageView(frame: container.bounds)
        caution.image = NSImage(named: NSImage.cautionName)
        caution.imageScaling = .scaleProportionallyUpOrDown
        caution.setAccessibilityElement(false)
        container.addSubview(caution)

        let badge = NSImageView(frame: NSRect(x: 38, y: 0, width: 26, height: 26))
        badge.image = Bundle.main.url(forResource: "AppIcon", withExtension: "icns")
            .flatMap { NSImage(contentsOf: $0) } ?? NSApp.applicationIconImage
        badge.imageScaling = .scaleProportionallyUpOrDown
        badge.setAccessibilityElement(false)
        container.addSubview(badge)
        return container
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("QuitConfirmationPanel uses programmatic initialization.") }
}

@MainActor
private final class QuitAlertSurface: TigerAquaBackgroundView {
    override var solidBodyColor: NSColor? { AquaGlassMaterial.color(0xf0f1f3) }
}
