import AppKit

@MainActor
final class MinuteDial: NSSlider, AquaFocusTarget {
    private static let pointerRadius: CGFloat = 26
    private let scaleImage = MinuteDial.loadImage("AquaMinuteDialScale")
    private let normalImage = MinuteDial.loadImage("AquaMinuteDialNormal")
    private let trackingImage = MinuteDial.loadImage("AquaMinuteDialTracking")
    private let disabledImage = MinuteDial.loadImage("AquaMinuteDialDisabled")
    private let pointerImage = MinuteDial.loadImage("AquaMinuteDialPointer")
    private let helpTag = AquaHelpTag()
    private var hoverArea: NSTrackingArea?
    private var isHovered = false
    private var isAdjusting = false
    private var scrollRemainder: Double = 0

    init() {
        super.init(frame: .zero)
        sliderType = .circular
        minValue = 0
        maxValue = 59
        doubleValue = 25
        isContinuous = true
        // The window's shared focus overlay follows the socket contour.
        focusRingType = .none
        setAccessibilityLabel("调节分钟")
        setAccessibilityIdentifier("Timer.MinuteDial")
        helpTag.text = "拖动或滚动旋钮可调整分钟"
        setAccessibilityHelp("点击、拖动、滚动或按方向键可调整分钟，范围为 0 至 59。")
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: 116, height: 108) }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var doubleValue: Double { didSet { needsDisplay = true } }
    override var integerValue: Int { didSet { needsDisplay = true } }
    override var isEnabled: Bool {
        didSet {
            if oldValue != isEnabled { scrollRemainder = 0 }
            if !isEnabled { helpTag.dismiss() }
            needsDisplay = true
        }
    }

    private var artworkRect: NSRect {
        NSRect(x: bounds.midX - 54, y: bounds.midY - 54, width: 108, height: 108)
    }

    var aquaFocusGeometry: AquaFocusGeometry {
        AquaFocusGeometry(rect: NSRect(x: bounds.midX - 41.5, y: bounds.midY - 41.5,
                                      width: 83, height: 83), shape: .ellipse)
    }

    override func draw(_ dirtyRect: NSRect) {
        draw(scaleImage, in: NSRect(x: bounds.midX - 58, y: bounds.midY - 54, width: 116, height: 108))
        draw(!isEnabled ? disabledImage : isAdjusting ? trackingImage : normalImage, in: artworkRect)
        if isEnabled && isHovered && !isAdjusting {
            NSColor(calibratedRed: 0.976, green: 1, blue: 0.945, alpha: 0.7).setStroke()
            let rim = NSBezierPath(ovalIn: NSRect(x: bounds.midX - 39.5, y: bounds.midY - 39.5,
                                                  width: 79, height: 79))
            rim.lineWidth = 0.65
            rim.stroke()
        }
        // Translate the dimple without rotating its lighting or the pearl face.
        let angle = CGFloat(doubleValue) * .pi / 30
        let pointerCenter = NSPoint(x: bounds.midX + sin(angle) * Self.pointerRadius,
                                    y: bounds.midY - cos(angle) * Self.pointerRadius)
        draw(pointerImage, in: NSRect(x: pointerCenter.x - 7, y: pointerCenter.y - 7,
                                     width: 14, height: 14), opacity: isEnabled ? 1 : 0.43)
    }

    private func draw(_ image: NSImage, in rect: NSRect, opacity: CGFloat = 1) {
        image.draw(in: rect, from: .zero, operation: .sourceOver,
                   fraction: opacity, respectFlipped: true, hints: nil)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self)
        addTrackingArea(area)
        hoverArea = area
        if let window {
            isHovered = bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
        }
        needsDisplay = true
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        helpTag.attach(to: self)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
        if let window {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(windowFocusChanged),
                                                       name: name, object: window)
            }
        }
    }

    @objc private func windowFocusChanged() { needsDisplay = true }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let window else { return }
        window.makeFirstResponder(self)
        scrollRemainder = 0
        isAdjusting = true
        needsDisplay = true
        defer {
            isAdjusting = false
            isHovered = bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
            needsDisplay = true
        }
        updateFromMouse(event)
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            updateFromMouse(next)
            if next.type == .leftMouseUp { break }
        }
    }

    private func updateFromMouse(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let dx = point.x - bounds.midX
        let dy = bounds.midY - point.y
        guard hypot(dx, dy) > 6 else { return }
        var angle = atan2(dx, dy)
        if angle < 0 { angle += 2 * .pi }
        // Sixty equal positions match the scale; 59 stays separate from 0.
        setMinuteValue(Double(Int((angle * 30 / .pi).rounded()) % 60))
    }

    override func scrollWheel(with event: NSEvent) {
        guard isEnabled else { return }
        let delta = abs(event.scrollingDeltaY) >= abs(event.scrollingDeltaX)
            ? event.scrollingDeltaY : event.scrollingDeltaX
        guard delta != 0 else { return }
        let movement = event.hasPreciseScrollingDeltas ? Double(delta) / 12 : (delta > 0 ? 1.0 : -1.0)
        scrollRemainder += movement
        let steps = scrollRemainder.rounded(.towardZero)
        guard steps != 0 else { return }
        scrollRemainder -= steps
        setMinuteValue(doubleValue + steps)
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
            super.keyDown(with: event)
            return
        }
        needsDisplay = true
        switch event.keyCode {
        case 123, 125: setMinuteValue(doubleValue - 1) // Left / down
        case 124, 126: setMinuteValue(doubleValue + 1) // Right / up
        case 115: setMinuteValue(minValue) // Home
        case 119: setMinuteValue(maxValue) // End
        case 116: setMinuteValue(doubleValue + 10) // Page up
        case 121: setMinuteValue(doubleValue - 10) // Page down
        default: super.keyDown(with: event)
        }
    }

    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }
        setMinuteValue(doubleValue + 1)
        return true
    }

    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }
        setMinuteValue(doubleValue - 1)
        return true
    }

    private func setMinuteValue(_ value: Double) {
        let minute = min(maxValue, max(minValue, value.rounded()))
        guard minute != doubleValue else { return }
        doubleValue = minute
        if let action { sendAction(action, to: target) }
    }

    private static func loadImage(_ name: String) -> NSImage {
        guard let image = NSImage(named: NSImage.Name(name)) else {
            preconditionFailure("Missing Aqua minute dial asset: \(name)")
        }
        return image
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MinuteDial uses programmatic initialization.")
    }
}
