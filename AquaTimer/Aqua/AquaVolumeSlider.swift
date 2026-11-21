import AppKit

/// The cell supplies the Aqua artwork while NSSlider handles hit testing and value changes.
@MainActor
final class AquaVolumeSlider: NSSlider, AquaFocusTarget {
    private var isTrackingMouse = false

    init() {
        super.init(frame: .zero)
        cell = AquaVolumeSliderCell()
        minValue = 0
        maxValue = 1
        doubleValue = 0.7
        focusRingType = .none
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        isTrackingMouse = isEnabled
        needsDisplay = true
        defer {
            isTrackingMouse = false
            needsDisplay = true
        }
        super.mouseDown(with: event)
    }

    var aquaFocusGeometry: AquaFocusGeometry {
        let knob = (cell as? NSSliderCell)?.knobRect(flipped: isFlipped) ?? bounds
        // Visible diameter in the SVG. The rest of the artwork rectangle is transparent padding.
        let diameter: CGFloat = 13.3
        let outline = NSRect(x: knob.midX - diameter / 2, y: knob.midY - diameter / 2,
                             width: diameter, height: diameter)
        return AquaFocusGeometry(rect: outline, shape: .ellipse)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("AquaVolumeSlider uses programmatic initialization.") }

    private final class AquaVolumeSliderCell: NSSliderCell {
        override func drawBar(inside rect: NSRect, flipped: Bool) {
            let controlBounds = controlView?.bounds ?? rect
            let name = isEnabled ? "AquaSliderTrack" : "AquaSliderTrackDisabled"
            let artwork = NSRect(x: controlBounds.minX, y: rect.midY - 4,
                                 width: controlBounds.width, height: 8)
            drawArtwork(name, in: artwork)
        }

        override func drawKnob(_ knobRect: NSRect) {
            let tracking = (controlView as? AquaVolumeSlider)?.isTrackingMouse == true
            let name = if !isEnabled { "AquaSliderThumbDisabled" }
                else if tracking { "AquaSliderThumbDragging" }
                else { "AquaSliderThumbNormal" }
            let artwork = NSRect(x: knobRect.midX - 9.5, y: knobRect.midY - 9.5,
                                 width: 19, height: 19)
            drawArtwork(name, in: artwork)
        }

        private func drawArtwork(_ name: String, in rect: NSRect) {
            guard let image = NSImage(named: NSImage.Name(name)) else {
                preconditionFailure("Missing Aqua slider artwork: \(name)")
            }
            image.draw(in: rect, from: .zero, operation: .sourceOver,
                       fraction: 1, respectFlipped: true, hints: nil)
        }
    }
}
