import AppKit

/// The glass surface shared by controls on the standard Aqua window background.
@MainActor
enum AquaGlassMaterial {
    struct Palette {
        let body: CGGradient
        let reflection: CGGradient
        let edge: CGGradient
        var endTint: CGGradient? = nil
        var shadowOpacity: CGFloat = 0.31
    }

    static let clear = Palette(
        body: gradient([(0, 0xbec1c4), (0.435, 0xd9dbe0), (0.68, 0xeff0f3),
                        (0.84, 0xfafafa), (0.90, 0xfefdfe), (1, 0xfefdfe)]),
        reflection: gradient([(0, 0xe5e6e8), (0.075, 0xfafafb), (0.24, 0xeff0f2),
                               (0.34, 0xededf0), (0.43, 0xeeeff1)]),
        edge: gradient([(0, 0x687078), (0.23, 0x9299a2), (0.47, 0x8d959f),
                        (0.75, 0x9aa0a6), (1, 0x6c737a)])
    )

    static let blue = Palette(
        body: gradient([(0, 0x657fa5), (0.435, 0x78b3dd), (0.55, 0x81c1e7),
                        (0.78, 0xa2d8ef), (0.94, 0xb7e4f0), (1, 0xb7e4f0)]),
        reflection: gradient([(0, 0x8da4c4), (0.075, 0xbdd2ee), (0.24, 0xabccea), (0.42, 0x92c5e9)]),
        edge: gradient([(0, 0x475477), (0.38, 0x628dbb), (0.61, 0x638fb9),
                        (0.86, 0x799aa9), (1, 0x677b80)]),
        endTint: CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                            colors: [0.42, 0.12, 0, 0, 0.12, 0.42].map {
                                color(0x337bb5, alpha: $0).cgColor
                            } as CFArray,
                            locations: [0, 0.085, 0.2, 0.8, 0.915, 1])
    )

    static let disabled = Palette(
        body: gradient([(0, 0xd9dadd), (0.43, 0xdfe0e2), (1, 0xf3f3f4)]),
        reflection: gradient([(0, 0xe7e8e9), (0.14, 0xf3f3f4), (0.48, 0xebeced)]),
        edge: gradient([(0, 0xb9bec3), (1, 0xb9bec3)]),
        shadowOpacity: 0.07
    )

    /// Paints a glass face in flipped view coordinates. The caller can supply
    /// another contour while keeping the light and color relative to `rect`.
    static func draw(in rect: NSRect, outline: CGPath, palette: Palette, pressed: Bool = false) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottom = CGPoint(x: rect.midX, y: rect.maxY)

        // A thin contact shadow follows the silhouette below the face.
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = color(0x39424a, alpha: palette.shadowOpacity)
        shadow.shadowOffset = NSSize(width: 0, height: pressed ? -1.1 : -1.3)
        shadow.shadowBlurRadius = 1.2
        shadow.set()
        context.setFillColor(color(0xf1f2f3).cgColor)
        context.addPath(outline)
        context.fillPath()
        NSGraphicsContext.restoreGraphicsState()

        context.saveGState()
        context.addPath(outline)
        context.clip()
        context.drawLinearGradient(palette.body, start: top, end: bottom, options: [])

        context.saveGState()
        context.addPath(reflection(in: rect))
        context.clip()
        context.drawLinearGradient(palette.reflection, start: top, end: bottom,
                                   options: .drawsAfterEndLocation)
        context.restoreGState()

        if let endTint = palette.endTint {
            context.drawLinearGradient(endTint, start: CGPoint(x: rect.minX, y: rect.midY),
                                       end: CGPoint(x: rect.maxX, y: rect.midY), options: [])
        }

        // Clip the outer half of the stroke so the edge stays inside the face.
        context.addPath(outline)
        context.setLineWidth(2)
        context.replacePathWithStrokedPath()
        context.clip()
        context.drawLinearGradient(palette.edge, start: top, end: bottom, options: [])
        context.restoreGState()
    }

    private static func reflection(in rect: NSRect) -> CGPath {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x / 68 * rect.width, y: rect.minY + y / 20 * rect.height)
        }
        let path = CGMutablePath()
        path.move(to: point(0, 7.35))
        path.addCurve(to: point(14, 8.55), control1: point(3.5, 8.35), control2: point(7.5, 8.52))
        path.addCurve(to: point(54, 8.55), control1: point(26, 8.6), control2: point(42, 8.6))
        path.addCurve(to: point(68, 7.35), control1: point(60.5, 8.52), control2: point(64.5, 8.35))
        path.addLine(to: point(68, 0))
        path.addLine(to: point(0, 0))
        path.closeSubpath()
        return path
    }

    private static func gradient(_ stops: [(CGFloat, UInt32)]) -> CGGradient {
        CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                   colors: stops.map { color($0.1).cgColor } as CFArray,
                   locations: stops.map { $0.0 })!
    }

    static func color(_ rgb: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat((rgb >> 16) & 0xff) / 255,
                green: CGFloat((rgb >> 8) & 0xff) / 255,
                blue: CGFloat(rgb & 0xff) / 255, alpha: alpha)
    }
}
