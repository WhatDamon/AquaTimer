import AppKit

@MainActor
final class GeneralSettingsViewController: SettingsPaneViewController, NSTextFieldDelegate {
    private static let durationHint = "小时填 0–23，分和秒填 0–59。总时长至少 1 秒。"
    private let fixed = AquaSelectionButton(label: "使用固定时长", kind: .radio)
    private let lastUsed = AquaSelectionButton(label: "记住上次设定的时长", kind: .radio)
    private let fields = ["0", "25", "0"].map { AquaDurationField(string: $0, allowsTextUndo: true) }
    private let validation = SettingsLayout.note("", lines: 1)
    private let rememberArea = AquaSelectionButton(label: "记住展开／收起状态", kind: .checkbox)
    private let confirmQuit = AquaSelectionButton(label: "计时期间退出前确认", kind: .checkbox)
    private var invalidDraft = false

    override func buildContents() {
        fixed.target = self; fixed.action = #selector(selectMode(_:))
        lastUsed.target = self; lastUsed.action = #selector(selectMode(_:))
        fixed.setAccessibilityIdentifier("Settings.StartupFixed")
        lastUsed.setAccessibilityIdentifier("Settings.StartupLastUsed")
        var durationViews: [NSView] = []
        for (index, field) in fields.enumerated() {
            field.delegate = self
            field.target = self; field.action = #selector(commitDuration(_:))
            field.cell?.sendsActionOnEndEditing = false
            let units = ["小时", "分钟", "秒"]
            field.setAccessibilityLabel("固定时长：" + units[index])
            field.setAccessibilityIdentifier("Settings.Duration.\(index)")
            let unitLabel = NSTextField(labelWithString: ["时", "分", "秒"][index])
            unitLabel.font = AquaTypography.font(ofSize: 11)
            unitLabel.textColor = AquaTypography.secondaryInk
            durationViews += [AquaDurationFieldChrome(field: field), unitLabel]
        }
        validation.textColor = .systemRed
        validation.setAccessibilityHidden(true)
        let durationRow = SettingsLayout.row(durationViews, spacing: 6)
        durationRow.alignment = .centerY
        let fixedDetails = SettingsLayout.indent(SettingsLayout.column([durationRow, validation], spacing: 4))
        let startup = SettingsLayout.column([fixed, fixedDetails, lastUsed,
            SettingsLayout.indent(SettingsLayout.note("启动时长的更改会在下次打开 AquaTimer 时生效。"))])
        startup.setCustomSpacing(4, after: lastUsed)
        addSection("启动时长：", body: startup, firstControl: fixed)

        rememberArea.target = self; rememberArea.action = #selector(changeRememberArea(_:))
        rememberArea.setAccessibilityIdentifier("Settings.RememberControlArea")
        addSection("控制区域：", body: SettingsLayout.column([rememberArea,
            SettingsLayout.indent(SettingsLayout.note("取消勾选后，下次启动会展开控制区域。"))
        ], spacing: 4), firstControl: rememberArea)

        confirmQuit.target = self; confirmQuit.action = #selector(changeConfirmQuit(_:))
        confirmQuit.setAccessibilityIdentifier("Settings.ConfirmQuit")
        addSection("退出应用：", body: SettingsLayout.column([confirmQuit,
            SettingsLayout.indent(SettingsLayout.note("关闭主窗口仍会继续计时。"))
        ], spacing: 4), firstControl: confirmQuit)
    }

    override func render() {
        let isFixed = settings.startupMode == .fixed
        fixed.state = isFixed ? .on : .off
        lastUsed.state = isFixed ? .off : .on
        fields.forEach { $0.isEnabled = isFixed }
        if !invalidDraft && !fields.contains(where: { $0.currentEditor() != nil }) {
            let seconds = settings.fixedDuration
            for (field, value) in zip(fields, [seconds / 3600, seconds / 60 % 60, seconds % 60]) {
                field.integerValue = value
            }
        }
        let issue = invalidDraft && isFixed ? values.issue : nil
        validation.stringValue = issue?.message ?? Self.durationHint
        validation.textColor = issue == nil ? AquaTypography.secondaryInk : .systemRed
        validation.alphaValue = isFixed ? 1 : 0
        validation.setAccessibilityHidden(!isFixed)
        for (index, field) in fields.enumerated() {
            field.setAccessibilityHelp(issue?.fieldIndex == index ? issue?.message : nil)
        }
        rememberArea.state = settings.rememberControlArea ? .on : .off
        confirmQuit.state = settings.confirmQuit ? .on : .off
    }

    override func prepareForPresentation() { invalidDraft = false; super.prepareForPresentation() }

    private var values: DurationInputValues {
        DurationInputValues(hours: fields[0].stringValue, minutes: fields[1].stringValue, seconds: fields[2].stringValue)
    }

    @objc private func selectMode(_ sender: NSButton) {
        view.window?.makeFirstResponder(nil)
        invalidDraft = false
        settings.startupMode = sender === fixed ? .fixed : .lastUsed
        render()
    }

    func controlTextDidChange(_ obj: Notification) {
        validation.stringValue = Self.durationHint
        validation.textColor = AquaTypography.secondaryInk
        validation.setAccessibilityHidden(false)
        fields.forEach { $0.setAccessibilityHelp(nil) }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard settings.startupMode == .fixed else { return }
        let values = values
        if let seconds = CountdownDuration.seconds(hours: values.hours, minutes: values.minutes, seconds: values.seconds) {
            invalidDraft = false
            settings.fixedDuration = seconds
        } else { invalidDraft = true }
        render()
    }

    @objc private func commitDuration(_ sender: Any?) { view.window?.makeFirstResponder(nil) }
    @objc private func changeRememberArea(_ sender: NSButton) { settings.rememberControlArea = sender.state == .on }
    @objc private func changeConfirmQuit(_ sender: NSButton) { settings.confirmQuit = sender.state == .on }
}
