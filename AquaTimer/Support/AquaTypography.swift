import AppKit
import CoreText

@MainActor
enum AquaTypography {
    static let secondaryInk = NSColor(srgbRed: 59.0 / 255, green: 59.0 / 255, blue: 59.0 / 255, alpha: 1)
    private static let lcdGraphicsFont: CGFont = {
        guard let url = Bundle.main.url(forResource: "DSEG7Classic-BoldItalic", withExtension: "ttf",
                                        subdirectory: "Fonts"),
              let provider = CGDataProvider(url: url as CFURL),
              let font = CGFont(provider) else {
            preconditionFailure("Missing or invalid bundled DSEG LCD font.")
        }
        return font
    }()

    static func lcdFont(ofSize size: CGFloat) -> NSFont {
        // Load the bundled face directly, without installing or resolving a system font of the same name.
        CTFontCreateWithGraphicsFont(lcdGraphicsFont, size, nil, nil) as NSFont
    }

    static func font(ofSize size: CGFloat, emphasized: Bool = false) -> NSFont {
        let name = emphasized ? "LucidaGrande-Bold" : "LucidaGrande"
        let primary = NSFont(name: name, size: size)
            ?? NSFont(name: "LucidaGrande", size: size)
            ?? NSFont.systemFont(ofSize: size)
        let fallbacks = ["STXihei", "STHeiti", "STHeitiSC-Light", "STHeitiSC-Medium"]
            .compactMap { NSFont(name: $0, size: size)?.fontDescriptor }
        let descriptor = primary.fontDescriptor.addingAttributes([.cascadeList: fallbacks])
        return NSFont(descriptor: descriptor, size: size) ?? primary
    }
}
