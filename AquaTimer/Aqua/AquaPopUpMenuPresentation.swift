import AppKit

/// Owns the menu panel and the event monitor for one visible pop-up.
@MainActor
final class AquaPopUpMenuPresentation: NSObject {
    private weak var button: AquaPopUpButton?
    private weak var owner: NSWindow?
    private let panel: NSPanel
    let menuView: AquaPopUpMenuView
    private let buttonFrame: NSRect
    private var eventMonitor: Any?
    private var openingWithMouse: Bool
    private var trackingClick = false
    private var typing = ""
    private var lastTyped: TimeInterval = 0

    init(button: AquaPopUpButton, owner: NSWindow, openingWithMouse: Bool) {
        self.button = button
        self.owner = owner
        self.openingWithMouse = openingWithMouse
        let buttonFrame = owner.convertToScreen(button.convert(button.face, to: nil))
        self.buttonFrame = buttonFrame
        let width = buttonFrame.width - AquaPopUpButton.capWidth + AquaPopUpMenuView.leftOutset
        let menuView = AquaPopUpMenuView(items: button.itemArray, selected: button.indexOfSelectedItem,
                                        width: width, font: button.font ?? AquaTypography.font(ofSize: 13))
        self.menuView = menuView
        let selected = max(0, button.indexOfSelectedItem)
        let menuSize = menuView.face.size
        let proposed = NSRect(x: buttonFrame.minX - AquaPopUpMenuView.leftOutset,
                              y: buttonFrame.maxY + AquaPopUpMenuView.rowTopInset
                                  + CGFloat(selected) * AquaPopUpButton.faceHeight - menuSize.height,
                              width: menuSize.width, height: menuSize.height)
        let visible = (NSScreen.screens.first { $0.frame.contains(NSPoint(x: buttonFrame.midX, y: buttonFrame.midY)) }
                       ?? owner.screen)?.visibleFrame
        var frame = proposed
        if let visible {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)
        }
        panel = MenuPanel(contentRect: frame.insetBy(dx: -AquaPopUpMenuView.shadowInset,
                                                   dy: -AquaPopUpMenuView.shadowInset),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
        panel.isExcludedFromWindowsMenu = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.contentView = menuView
        panel.acceptsMouseMovedEvents = true
        panel.setAccessibilityElement(false)
        menuView.setAccessibilityParent(button)
        menuView.choose = { [weak self] in self?.dismiss(selection: $0) }
    }

    func show() {
        guard let owner else { return }
        owner.addChildWindow(panel, ordered: .above)
        panel.orderFront(nil)
        let center = NotificationCenter.default
        for name in [NSWindow.didResignKeyNotification, NSWindow.willCloseNotification,
                     NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            center.addObserver(self, selector: #selector(ownerChanged), name: name, object: owner)
        }
        center.addObserver(self, selector: #selector(ownerChanged),
                           name: NSApplication.didResignActiveNotification, object: NSApp)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [
            .leftMouseDown, .leftMouseDragged, .leftMouseUp, .mouseMoved, .rightMouseDown, .otherMouseDown, .keyDown
        ]) { [weak self] event in
            guard let self else { return event }
            return self.handle(event)
        }
    }

    func dismiss(selection: Int? = nil) {
        NotificationCenter.default.removeObserver(self)
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor); self.eventMonitor = nil }
        owner?.removeChildWindow(panel)
        panel.orderOut(nil)
        button?.menuDidDismiss(self, selection: selection)
    }

    @objc private func ownerChanged() { dismiss() }

    // The owner keeps keyboard focus while this panel receives mouse input.
    private final class MenuPanel: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }

        override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
            // The visible menu face was already constrained before adding shadow insets.
            frameRect
        }
    }

    private func handle(_ event: NSEvent) -> NSEvent? {
        if event.type == .keyDown { return handleKey(event) }
        let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
        let menuPoint = menuView.convert(panel.convertPoint(fromScreen: point), from: nil)
        let row = menuView.index(at: menuPoint)
        switch event.type {
        case .mouseMoved, .leftMouseDragged:
            menuView.highlighted = row
            return event
        case .leftMouseDown:
            guard menuView.face.contains(menuPoint) else {
                dismiss()
                return buttonFrame.contains(point) || event.window === owner || event.window === panel ? nil : event
            }
            trackingClick = true
            menuView.highlighted = row
            return nil
        case .leftMouseUp:
            if openingWithMouse {
                openingWithMouse = false
                if buttonFrame.contains(point) { return nil }
                dismiss(selection: row)
            } else if trackingClick {
                dismiss(selection: row)
            }
            return nil
        default:
            dismiss()
            return event.window === panel ? nil : event
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 53: dismiss() // Escape
        case 36, 49, 76: dismiss(selection: menuView.highlighted ?? menuView.selected)
        case 125: menuView.moveHighlight(by: 1)
        case 126: menuView.moveHighlight(by: -1)
        case 48: dismiss(); return event // Tab
        default:
            if !event.modifierFlags.intersection([.command, .control, .option]).isEmpty {
                dismiss()
                return event
            }
            if let chars = event.characters, !chars.isEmpty,
               chars.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) }) {
                if event.timestamp - lastTyped > 0.75 { typing = "" }
                typing += chars
                lastTyped = event.timestamp
                menuView.highlightPrefix(typing)
            }
        }
        return nil
    }
}
