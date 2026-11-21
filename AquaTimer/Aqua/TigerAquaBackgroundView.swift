import AppKit

/// Classic Aqua rounds the titlebar corners and keeps the bottom corners square.
enum TigerWindowShape {
    case rounded
    case standardAqua
    case square

    func path(in rect: NSRect, flipped: Bool = false) -> CGPath {
        if self == .square { return CGPath(rect: rect, transform: nil) }
        if self == .rounded {
            return CGPath(roundedRect: rect, cornerWidth: 7, cornerHeight: 7, transform: nil)
        }
        let radius: CGFloat = min(6, min(rect.width, rect.height) / 2)
        let top = flipped ? rect.minY : rect.maxY
        let bottom = flipped ? rect.maxY : rect.minY
        let direction: CGFloat = flipped ? 1 : -1
        let tangent = radius * (1 - 0.5522847498)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: bottom))
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom))
        path.addLine(to: CGPoint(x: rect.maxX, y: top + direction * radius))
        path.addCurve(to: CGPoint(x: rect.maxX - radius, y: top),
                      control1: CGPoint(x: rect.maxX, y: top + direction * tangent),
                      control2: CGPoint(x: rect.maxX - tangent, y: top))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: top))
        path.addCurve(to: CGPoint(x: rect.minX, y: top + direction * radius),
                      control1: CGPoint(x: rect.minX + tangent, y: top),
                      control2: CGPoint(x: rect.minX, y: top + direction * tangent))
        path.closeSubpath()
        return path
    }
}

/// The standard Aqua surface from the 2005 HIG, separate from the metal timer shell.
@MainActor
class TigerAquaBackgroundView: NSView {
    static let titlebarHeight: CGFloat = 22
    private var isWindowActive = false
    var solidBodyColor: NSColor? { nil }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        appearance = NSAppearance(named: .aqua)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.saveGState()
        defer { context.restoreGState() }
        context.addPath(TigerWindowShape.standardAqua.path(in: bounds, flipped: true))
        context.clip()
        (solidBodyColor ?? NSColor(srgbRed: 239.0 / 255, green: 239.0 / 255,
                                    blue: 239.0 / 255, alpha: 1)).setFill()
        bounds.fill()
        if solidBodyColor == nil {
            NSColor(srgbRed: 233.0 / 255, green: 233.0 / 255, blue: 233.0 / 255, alpha: 1).setFill()
            for y in stride(from: Self.titlebarHeight, to: bounds.maxY, by: 2) {
                NSRect(x: 0, y: y, width: bounds.width, height: 1).fill()
            }
        }
        let header = NSRect(x: 0, y: 0, width: bounds.width, height: Self.titlebarHeight)
        let shades: [CGFloat] = isWindowActive ? [0.98, 0.93, 0.87, 0.82] : [0.97, 0.95, 0.93, 0.91]
        let colors = shades.map { NSColor(srgbRed: $0, green: $0, blue: $0, alpha: 1) }
        NSGradient(colorsAndLocations: (colors[0], 0), (colors[1], 0.12),
                   (colors[2], 0.65), (colors[3], 1))?.draw(in: header, angle: 90)
        NSColor(calibratedWhite: isWindowActive ? 0.57 : 0.73, alpha: 1).setFill()
        NSRect(x: 0, y: Self.titlebarHeight - 0.5, width: bounds.width, height: 0.5).fill()
        context.addPath(TigerWindowShape.standardAqua.path(in: bounds.insetBy(dx: 0.25, dy: 0.25), flipped: true))
        context.setStrokeColor(NSColor(calibratedWhite: 0.53, alpha: 0.65).cgColor)
        context.setLineWidth(0.5)
        context.strokePath()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self)
        if let window {
            for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(refreshAppearance),
                                                       name: name, object: window)
            }
            for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
                NotificationCenter.default.addObserver(self, selector: #selector(refreshAppearance), name: name, object: NSApp)
            }
        }
        refreshAppearance()
    }

    @objc private func refreshAppearance() {
        isWindowActive = window?.isKeyWindow == true && NSApp.isActive
        needsDisplay = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("TigerAquaBackgroundView uses programmatic initialization.") }
}
