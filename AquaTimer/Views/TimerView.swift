import AppKit

@MainActor
final class TimerView: NSView {
    let display = TimerDisplayView()
    let minuteDial = MinuteDial()
    let hoursField = AquaDurationField(string: "0")
    let minutesField = AquaDurationField(string: "25")
    let secondsField = AquaDurationField(string: "0")
    let validationLabel = NSTextField(labelWithString: "")
    let primaryButton = AquaActionButton(title: "开始", role: .primary, icon: .play)
    let resetButton = AquaActionButton(title: "重置", role: .reset, icon: .reset)

    private let lowerControlArea = NSStackView()
    private let contentStack = NSStackView()
    private static let horizontalInset: CGFloat = 16
    private static let verticalInset: CGFloat = 12

    var compactHeight: CGFloat { display.fittingSize.height + Self.verticalInset * 2 }
    var expandedHeight: CGFloat { contentStack.fittingSize.height + Self.verticalInset * 2 }

    func setControlsCollapsed(_ collapsed: Bool) {
        lowerControlArea.isHidden = collapsed
    }

    var durationFields: [NSTextField] {
        [hoursField, minutesField, secondsField]
    }

    init() {
        super.init(frame: .zero)

        let inputs = NSStackView(views: [
            durationInput(hoursField, unit: "小时", identifier: "Timer.Hours"),
            durationInput(minutesField, unit: "分钟", identifier: "Timer.Minutes"),
            durationInput(secondsField, unit: "秒", identifier: "Timer.Seconds")
        ])
        // Each chrome has 4 pt of focus padding: 4 + 2 + 4 = 10 pt between visible fields.
        inputs.spacing = 2

        NSLayoutConstraint.activate([
            minuteDial.widthAnchor.constraint(equalToConstant: 116),
            minuteDial.heightAnchor.constraint(equalToConstant: 108)
        ])
        let dialLabel = NSTextField(labelWithString: "调节分钟")
        dialLabel.font = AquaTypography.font(ofSize: 11)
        dialLabel.textColor = AquaTypography.secondaryInk
        let dial = NSStackView(views: [minuteDial, dialLabel])
        dial.orientation = .vertical
        dial.alignment = .centerX
        dial.spacing = 4
        dial.widthAnchor.constraint(equalToConstant: 116).isActive = true

        let settingLabel = NSTextField(labelWithString: "设置时长")
        settingLabel.font = AquaTypography.font(ofSize: 13, emphasized: true)
        let settings = NSStackView(views: [settingLabel, inputs, validationLabel])
        settings.orientation = .vertical
        settings.alignment = .leading
        settings.spacing = 8
        settings.setHuggingPriority(.required, for: .vertical)
        let controls = NSStackView(views: [dial, settings])
        controls.alignment = .centerY
        controls.spacing = 16

        validationLabel.font = AquaTypography.font(ofSize: 12)
        validationLabel.textColor = NSColor(calibratedRed: 0.588, green: 0.231, blue: 0.196, alpha: 1)
        validationLabel.alignment = .left
        validationLabel.maximumNumberOfLines = 1
        validationLabel.lineBreakMode = .byTruncatingTail
        validationLabel.heightAnchor.constraint(equalToConstant: 18).isActive = true
        validationLabel.setAccessibilityHidden(true)
        validationLabel.widthAnchor.constraint(equalTo: settings.widthAnchor).isActive = true

        primaryButton.setAccessibilityIdentifier("Timer.Primary")
        resetButton.setAccessibilityIdentifier("Timer.Reset")
        let buttons = NSStackView(views: [primaryButton, resetButton])
        // Four transparent points on each side contain the full focus glow: 4 + 4 + 4 = 12 pt.
        buttons.spacing = 4

        let hint = NSTextField(labelWithString: "关闭窗口会继续计时。退出 AquaTimer 会停止计时。")
        hint.font = AquaTypography.font(ofSize: 11)
        hint.textColor = AquaTypography.secondaryInk

        lowerControlArea.orientation = .vertical
        lowerControlArea.alignment = .centerX
        // Expanding each button's hit height by 8 pt consumes 4 pt of the gap on either side.
        lowerControlArea.spacing = 6
        [controls, buttons, hint].forEach { lowerControlArea.addArrangedSubview($0) }
        let stack = contentStack
        [display, lowerControlArea].forEach { stack.addArrangedSubview($0) }
        stack.detachesHiddenViews = true
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontalInset - 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontalInset + 4),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Self.verticalInset),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Self.verticalInset),
            // Visible content retains 16 pt side insets; only button focus padding extends to 12 pt.
            display.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -8),
            lowerControlArea.widthAnchor.constraint(equalTo: stack.widthAnchor),
            controls.widthAnchor.constraint(equalTo: lowerControlArea.widthAnchor, constant: -8),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])

        hoursField.nextKeyView = minutesField
        minutesField.nextKeyView = secondsField
        secondsField.nextKeyView = primaryButton
        primaryButton.nextKeyView = resetButton
        resetButton.nextKeyView = minuteDial
        minuteDial.nextKeyView = hoursField
    }

    private func durationInput(_ field: AquaDurationField, unit: String, identifier: String) -> NSView {
        field.setAccessibilityLabel(unit)
        field.setAccessibilityIdentifier(identifier)
        let chrome = AquaDurationFieldChrome(field: field)

        let label = NSTextField(labelWithString: unit)
        label.font = AquaTypography.font(ofSize: 11)
        label.textColor = AquaTypography.secondaryInk
        let stack = NSStackView(views: [chrome, label])
        stack.orientation = .vertical
        stack.alignment = .centerX
        // The chrome's bottom padding already supplies the 4 pt gap above the unit label.
        stack.spacing = 0
        return stack
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TimerView uses programmatic initialization.")
    }
}
