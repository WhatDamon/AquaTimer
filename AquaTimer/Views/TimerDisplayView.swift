import AppKit

@MainActor
final class TimerDisplayView: NSView {
    let timeLabel = LCDTimeField()
    private let statusIndicator = LCDStatusView()
    let progressIndicator = LCDProgressIndicator()
    private let background: NSImage
    private let grain: NSImage

    init() {
        background = LCDMaterial.image(named: "LCDBackground")
        grain = LCDMaterial.image(named: "LCDGrain")
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 3
        layer?.masksToBounds = true

        let caption = NSTextField(labelWithString: "剩余时间")
        caption.font = AquaTypography.font(ofSize: 11)
        caption.textColor = LCDMaterial.silkInk
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let header = NSStackView(views: [caption, spacer, statusIndicator])
        header.alignment = .centerY

        progressIndicator.style = .bar
        progressIndicator.controlSize = .small
        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.setAccessibilityLabel("计时进度")
        progressIndicator.setAccessibilityIdentifier("Timer.Progress")

        let stack = NSStackView(views: [header, timeLabel, progressIndicator])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        let glass = LCDGlassView()
        glass.translatesAutoresizingMaskIntoConstraints = false
        addSubview(glass, positioned: .above, relativeTo: stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            timeLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusIndicator.widthAnchor.constraint(equalToConstant: 48),
            statusIndicator.heightAnchor.constraint(equalToConstant: 14),
            progressIndicator.widthAnchor.constraint(equalTo: stack.widthAnchor),
            progressIndicator.heightAnchor.constraint(equalToConstant: 6),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 132),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        LCDMaterial.drawPanel(background, in: bounds)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 1.5, yRadius: 1.5).addClip()
        let tile = grain.size
        var y: CGFloat = 2
        while y < bounds.height - 2 {
            var x: CGFloat = 2
            while x < bounds.width - 2 {
                let rect = NSRect(x: x, y: y, width: tile.width, height: tile.height)
                if rect.intersects(dirtyRect) {
                    grain.draw(in: rect, from: .zero, operation: .overlay,
                               fraction: 1, respectFlipped: true, hints: nil)
                }
                x += tile.width
            }
            y += tile.height
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    func showTime(_ seconds: TimeInterval?) {
        timeLabel.showTime(seconds)
    }

    func updateAppearance(for state: Countdown.State) {
        statusIndicator.state = state
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TimerDisplayView uses programmatic initialization.")
    }
}
