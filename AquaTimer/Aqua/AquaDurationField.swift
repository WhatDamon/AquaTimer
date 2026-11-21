import AppKit

/// A native text field with SVG chrome supplied by its surrounding view.
@MainActor
final class AquaDurationField: NSTextField, AquaFocusTarget {
    init(string: String, allowsTextUndo: Bool = false) {
        super.init(frame: .zero)
        let durationCell = AquaDurationFieldCell(textCell: string)
        durationCell.allowsTextUndo = allowsTextUndo
        cell = durationCell
        font = AquaTypography.font(ofSize: 13)
        alignment = .center
        isBezeled = false
        isBordered = false
        drawsBackground = false
        focusRingType = .none
        usesSingleLineMode = true
        isEditable = true
        isSelectable = true
        textColor = NSColor(calibratedWhite: 0.10, alpha: 1)
    }

    override var intrinsicContentSize: NSSize { NSSize(width: 50, height: 22) }
    override var mouseDownCanMoveWindow: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var isEnabled: Bool {
        didSet {
            textColor = NSColor(calibratedWhite: isEnabled ? 0.10 : 0.54, alpha: 1)
            superview?.needsDisplay = true
        }
    }

    var aquaFocusGeometry: AquaFocusGeometry {
        AquaFocusGeometry(rect: bounds, shape: .roundedRect(0))
    }

    func ownsAquaFocus(_ responder: NSResponder) -> Bool {
        responder === self || (cell as? AquaDurationFieldCell)?.ownsEditor(responder) == true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AquaDurationField uses programmatic initialization.")
    }
}

@MainActor
private final class AquaDurationFieldCell: NSTextFieldCell {
    // The main timer uses DurationInputHistory. Settings uses native text undo.
    var allowsTextUndo = false
    // Keep the Aqua selection color local to these fields rather than changing the shared window editor.
    private lazy var aquaEditor: NSTextView = {
        let editor = NSTextView(frame: .zero)
        editor.isFieldEditor = true
        editor.isRichText = false
        editor.allowsUndo = allowsTextUndo
        return editor
    }()

    override func fieldEditor(for controlView: NSView) -> NSTextView? { aquaEditor }

    func ownsEditor(_ responder: NSResponder?) -> Bool { responder === aquaEditor }

    override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let editor = super.setUpFieldEditorAttributes(textObj)
        if let editor = editor as? NSTextView {
            editor.drawsBackground = false
            editor.insertionPointColor = NSColor(calibratedWhite: 0.10, alpha: 1)
            editor.selectedTextAttributes = [
                .backgroundColor: NSColor(calibratedRed: 0.541, green: 0.761, blue: 0.882, alpha: 1),
                .foregroundColor: NSColor(calibratedWhite: 0.10, alpha: 1)
            ]
        }
        return editor
    }

    private func textRect(for bounds: NSRect) -> NSRect {
        let font = font ?? AquaTypography.font(ofSize: 13)
        let height = min(bounds.height, ceil(font.ascender - font.descender + font.leading))
        return NSRect(x: bounds.minX + 2, y: bounds.midY - height / 2,
                      width: max(0, bounds.width - 4), height: height)
    }

    override func drawingRect(forBounds rect: NSRect) -> NSRect { textRect(for: rect) }
    override func titleRect(forBounds rect: NSRect) -> NSRect { textRect(for: rect) }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard !isEnabled else {
            super.drawInterior(withFrame: cellFrame, in: controlView)
            return
        }
        // Keep the approved disabled contrast; the native cell would fade its already-gray text again.
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byClipping
        NSAttributedString(string: stringValue, attributes: [
            .font: font ?? AquaTypography.font(ofSize: 13),
            .foregroundColor: NSColor(calibratedWhite: 0.54, alpha: 1),
            .paragraphStyle: paragraph
        ]).draw(in: textRect(for: cellFrame))
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText,
                       delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: textRect(for: rect), in: controlView, editor: textObj,
                   delegate: delegate, event: event)
        controlView.superview?.needsDisplay = true
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText,
                         delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: textRect(for: rect), in: controlView, editor: textObj,
                     delegate: delegate, start: selStart, length: selLength)
        controlView.superview?.needsDisplay = true
    }

    override func endEditing(_ textObj: NSText) {
        let chrome = controlView?.superview
        super.endEditing(textObj)
        chrome?.needsDisplay = true
    }
}

/// Four transparent points around the 50×22 pt field contain the complete Aqua focus glow.
@MainActor
final class AquaDurationFieldChrome: NSView {
    private let field: AquaDurationField
    private let normalImage = AquaDurationFieldChrome.loadImage("AquaInputNormal")
    private let disabledImage = AquaDurationFieldChrome.loadImage("AquaInputDisabled")

    init(field: AquaDurationField) {
        self.field = field
        super.init(frame: .zero)
        field.translatesAutoresizingMaskIntoConstraints = false
        addSubview(field)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 58),
            heightAnchor.constraint(equalToConstant: 30),
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            field.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            field.widthAnchor.constraint(equalToConstant: 50),
            field.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    override var isFlipped: Bool { true }
    override var allowsVibrancy: Bool { false }
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        draw(field.isEnabled ? normalImage : disabledImage)
    }

    private func draw(_ image: NSImage) {
        image.draw(in: bounds, from: .zero, operation: .sourceOver,
                   fraction: 1, respectFlipped: true, hints: nil)
    }

    private static func loadImage(_ name: String) -> NSImage {
        guard let image = NSImage(named: NSImage.Name(name)) else {
            preconditionFailure("Missing Aqua input field asset: \(name)")
        }
        return image
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AquaDurationFieldChrome uses programmatic initialization.")
    }
}
