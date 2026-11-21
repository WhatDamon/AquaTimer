import AppKit

@MainActor
final class AquaWindowButton: NSButton, AquaFocusTarget {
    enum Role: String, CaseIterable {
        case close = "Close"
        case minimize = "Minimize"
        case zoom = "Zoom"

        var action: Selector {
            switch self {
            case .close: #selector(NSWindow.performClose(_:))
            case .minimize: #selector(NSWindow.performMiniaturize(_:))
            case .zoom: #selector(AquaWindow.toggleControlArea(_:))
            }
        }

        var label: String {
            switch self {
            case .close: "关闭"
            case .minimize: "最小化"
            case .zoom: "收起控制区域"
            }
        }

        var accessibilitySubrole: NSAccessibility.Subrole? {
            switch self {
            case .close: .closeButton
            case .minimize: .minimizeButton
            case .zoom: nil
            }
        }
    }

    let role: Role
    var isWindowActive = false {
        didSet { if oldValue != isWindowActive { needsDisplay = true } }
    }
    var showsSymbols = false {
        didSet { if oldValue != showsSymbols { needsDisplay = true } }
    }

    var controlsCollapsed = false {
        didSet { needsDisplay = true }
    }
    private let collapseHoverImage: NSImage?
    private let collapsePressedImage: NSImage?
    private let normalImage: NSImage
    private let hoverImage: NSImage
    private let pressedImage: NSImage
    private let inactiveImage: NSImage
    private let hitExtent: CGFloat
    private let artworkSize: CGFloat
    private let disabledArtworkOpacity: CGFloat

    init(role: Role, controlSize: CGFloat = 20, artworkSize: CGFloat = 18,
         disabledArtworkOpacity: CGFloat = 0.55) {
        self.role = role
        self.hitExtent = controlSize
        self.artworkSize = artworkSize
        self.disabledArtworkOpacity = disabledArtworkOpacity
        let prefix = "AquaWindow\(role.rawValue)"
        collapseHoverImage = role == .zoom ? Self.loadImage("AquaWindowZoomCollapseHover") : nil
        collapsePressedImage = role == .zoom ? Self.loadImage("AquaWindowZoomCollapsePressed") : nil
        normalImage = Self.loadImage("\(prefix)Normal")
        hoverImage = Self.loadImage("\(prefix)Hover")
        pressedImage = Self.loadImage("\(prefix)Pressed")
        inactiveImage = Self.loadImage("AquaWindowInactive")
        super.init(frame: .zero)

        title = ""
        setButtonType(.momentaryChange)
        isBordered = false
        image = normalImage
        alternateImage = pressedImage
        imagePosition = .imageOnly
        action = role.action
        focusRingType = .none
        setAccessibilityLabel(role.label)
        setAccessibilitySubrole(role.accessibilitySubrole)
        setAccessibilityIdentifier("Window.\(role.rawValue)")
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: controlSize),
            heightAnchor.constraint(equalToConstant: controlSize)
        ])
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }
    override var intrinsicContentSize: NSSize { NSSize(width: hitExtent, height: hitExtent) }

    private let helpTag = AquaHelpTag()

    func updateControlAreaHelp(_ text: String?) { helpTag.text = text }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if role == .zoom { helpTag.attach(to: self) }
    }

    private var artworkRect: NSRect {
        NSRect(x: bounds.midX - artworkSize / 2, y: bounds.midY - artworkSize / 2,
               width: artworkSize, height: artworkSize)
    }

    override func draw(_ dirtyRect: NSRect) {
        let artwork: NSImage
        if !isWindowActive || !isEnabled {
            artwork = inactiveImage
        } else if isHighlighted {
            artwork = (!controlsCollapsed ? collapsePressedImage : nil) ?? pressedImage
        } else if showsSymbols {
            artwork = (!controlsCollapsed ? collapseHoverImage : nil) ?? hoverImage
        } else {
            artwork = normalImage
        }
        artwork.draw(in: artworkRect, from: .zero, operation: .sourceOver,
                     fraction: isEnabled ? 1 : disabledArtworkOpacity, respectFlipped: true, hints: nil)
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    var aquaFocusGeometry: AquaFocusGeometry {
        AquaFocusGeometry(rect: artworkRect.insetBy(dx: 1, dy: 1), shape: .ellipse)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private static func loadImage(_ name: String) -> NSImage {
        guard let image = NSImage(named: NSImage.Name(name)) else {
            preconditionFailure("Missing Aqua window button asset: \(name)")
        }
        return image
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AquaWindowButton uses programmatic initialization.")
    }
}
