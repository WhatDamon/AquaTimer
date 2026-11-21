import AppKit

/// Three predefined LCD annunciators, with the native state description available to VoiceOver.
@MainActor
final class LCDStatusView: NSView {
    private let helpTag = AquaHelpTag()
    var state: Countdown.State = .idle {
        didSet {
            guard oldValue != state else { return }
            updateAccessibilityValue()
            needsDisplay = true
        }
    }

    init() {
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("计时状态")
        setAccessibilityIdentifier("Timer.Status")
        updateAccessibilityValue()
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: 48, height: 14) }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        helpTag.attach(to: self)
    }

    private func updateAccessibilityValue() {
        let description: String
        switch state {
        case .idle: description = "就绪"
        case .running: description = "计时中"
        case .paused: description = "已暂停"
        case .finished: description = "时间到"
        }
        setAccessibilityValue(description)
        helpTag.text = description
    }

    override func draw(_ dirtyRect: NSRect) {
        for index in 0..<3 {
            NSGraphicsContext.saveGraphicsState()
            let transform = NSAffineTransform()
            transform.translateX(by: CGFloat(index) * 18, yBy: (bounds.height - 12) / 2)
            transform.concat()
            let active = (index == 0 && state == .running)
                || (index == 1 && state == .paused)
                || (index == 2 && state == .finished)
            let color = active ? LCDMaterial.ink : LCDMaterial.inactiveInk
            color.setFill()
            color.setStroke()
            switch index {
            case 0:
                let triangle = NSBezierPath()
                triangle.move(to: NSPoint(x: 2, y: 1.5))
                triangle.line(to: NSPoint(x: 10.5, y: 6))
                triangle.line(to: NSPoint(x: 2, y: 10.5))
                triangle.close()
                triangle.fill()
            case 1:
                NSRect(x: 2, y: 1.5, width: 3, height: 9).fill()
                NSRect(x: 7, y: 1.5, width: 3, height: 9).fill()
            default:
                let bell = NSBezierPath()
                bell.move(to: NSPoint(x: 1.5, y: 9))
                bell.line(to: NSPoint(x: 3, y: 7.5))
                bell.line(to: NSPoint(x: 3, y: 4.5))
                bell.curve(to: NSPoint(x: 9, y: 4.5),
                           controlPoint1: NSPoint(x: 3, y: 0.8),
                           controlPoint2: NSPoint(x: 9, y: 0.8))
                bell.line(to: NSPoint(x: 9, y: 7.5))
                bell.line(to: NSPoint(x: 10.5, y: 9))
                bell.close()
                bell.lineWidth = 1.25
                bell.lineJoinStyle = .round
                bell.stroke()
                NSBezierPath(ovalIn: NSRect(x: 5, y: 10, width: 2, height: 1.5)).fill()
            }
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("LCDStatusView uses programmatic initialization.")
    }
}
