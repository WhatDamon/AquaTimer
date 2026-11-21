import AppKit

@MainActor
final class BrushedMetalBackgroundView: NSView {
    private static let cornerRadius: CGFloat = 7
    private let lighting: NSImage
    private let grain: NSImage
    private let topEdge: NSImage
    private let bottomEdge: NSImage
    var lightingHeight: CGFloat? {
        didSet { if oldValue != lightingHeight { needsDisplay = true } }
    }
    private var lastSize: NSSize = .zero

    init() {
        lighting = Self.loadImage("BrushedMetalLighting")
        grain = Self.loadImage("BrushedMetalGrain")
        topEdge = Self.loadImage("BrushedMetalTopEdge")
        bottomEdge = Self.loadImage("BrushedMetalBottomEdge")
        super.init(frame: .zero)
        appearance = NSAppearance(named: .aqua)
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize
        layer?.cornerRadius = Self.cornerRadius
        layer?.cornerCurve = .circular
        layer?.masksToBounds = true
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let lightingRect = NSRect(x: 0, y: 0, width: bounds.width,
                                  height: lightingHeight ?? bounds.height)
        lighting.draw(in: lightingRect, from: .zero, operation: .sourceOver,
                      fraction: 1, respectFlipped: true, hints: nil)

        // Lighting uses the expanded height; both it and the fixed-size grain stay anchored at the top.
        let tile = grain.size
        var y: CGFloat = 0
        while y < bounds.height {
            var x: CGFloat = 0
            while x < bounds.width {
                let rect = NSRect(x: x, y: y, width: tile.width, height: tile.height)
                if rect.intersects(dirtyRect) {
                    grain.draw(in: rect, from: .zero, operation: .overlay,
                               fraction: 1, respectFlipped: true, hints: nil)
                }
                x += tile.width
            }
            y += tile.height
        }

        // Edge rolls follow the visible shell; their depth never stretches with its height.
        topEdge.draw(in: NSRect(x: 0, y: 0, width: bounds.width, height: topEdge.size.height),
                     from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        bottomEdge.draw(in: NSRect(x: 0, y: bounds.height - bottomEdge.size.height,
                                  width: bounds.width, height: bottomEdge.size.height),
                        from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)

    }

    override func layout() {
        super.layout()
        let radius = Self.cornerRadius
        if bounds.size != lastSize || layer?.cornerRadius != radius {
            lastSize = bounds.size
            layer?.cornerRadius = radius
            needsDisplay = true
            window?.invalidateShadow()
        }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsDisplay = true
    }

    private static func loadImage(_ name: String) -> NSImage {
        guard let image = NSImage(named: NSImage.Name(name)), image.size.width > 0, image.size.height > 0 else {
            preconditionFailure("Missing brushed metal asset: \(name)")
        }
        return image
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BrushedMetalBackgroundView uses programmatic initialization.")
    }
}
