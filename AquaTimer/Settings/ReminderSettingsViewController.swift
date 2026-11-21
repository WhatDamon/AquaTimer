import AppKit
@preconcurrency import UserNotifications

@MainActor
final class ReminderSettingsViewController: SettingsPaneViewController {
    private static let volumeHint = "只调整 AquaTimer 的提示音量。"
    private let soundEnabled = AquaSelectionButton(label: "到时播放提示音", kind: .checkbox)
    private let tone = AquaPopUpButton()
    private let preview = AquaPushButton(label: "试听")
    private let volume = AquaVolumeSlider()
    private let volumeValue = NSTextField(labelWithString: "70%")
    private let playCount = AquaPopUpButton()
    private let soundStatus = SettingsLayout.note(volumeHint, lines: 1)
    private let notifications = AquaSelectionButton(label: "后台到时发送系统通知", kind: .checkbox)
    private let notificationStatus = SettingsLayout.note("开启后，macOS 会询问是否允许通知。", lines: 2)
    private var requestingPermission = false
    private var status: UNAuthorizationStatus = .notDetermined
    private var permissionError = false
    private var authorizationRevision = 0

    override func buildContents() {
        soundEnabled.target = self; soundEnabled.action = #selector(changeSound(_:))
        soundEnabled.setAccessibilityIdentifier("Settings.SoundEnabled")
        tone.addItems(withTitles: AppSettings.Tone.allCases.map(\.title))
        tone.target = self; tone.action = #selector(changeTone(_:))
        tone.widthAnchor.constraint(equalToConstant: 190).isActive = true
        tone.setAccessibilityLabel("提示音")
        tone.setAccessibilityIdentifier("Settings.Tone")
        preview.target = self; preview.action = #selector(previewSound(_:))
        preview.setAccessibilityIdentifier("Settings.PreviewSound")
        volume.target = self; volume.action = #selector(changeVolume(_:))
        volume.isContinuous = true
        volume.widthAnchor.constraint(equalToConstant: 210).isActive = true
        volume.setAccessibilityLabel("提示音量")
        volume.setAccessibilityIdentifier("Settings.Volume")
        volumeValue.widthAnchor.constraint(equalToConstant: 42).isActive = true
        volumeValue.alignment = .right
        volumeValue.font = AquaTypography.font(ofSize: 13)
        playCount.addItems(withTitles: ["播放一次", "播放三次"])
        playCount.target = self; playCount.action = #selector(changePlayCount(_:))
        playCount.setAccessibilityLabel("提示音播放次数")
        playCount.setAccessibilityIdentifier("Settings.PlayCount")
        playCount.widthAnchor.constraint(equalToConstant: 190).isActive = true
        let volumeRow = SettingsLayout.row([volume, volumeValue])
        volumeRow.alignment = .centerY
        let audio = SettingsLayout.column([
            SettingsLayout.row([tone, preview]), volumeRow, soundStatus, playCount,
            SettingsLayout.note("要停止声音，请选取「计时器」→「停止提醒」。")
        ])
        audio.setCustomSpacing(4, after: volumeRow)
        audio.setCustomSpacing(4, after: playCount)
        let sound = SettingsLayout.column([soundEnabled, SettingsLayout.indent(audio)])
        addSection("声音：", body: sound, firstControl: soundEnabled)

        notifications.target = self; notifications.action = #selector(changeNotifications(_:))
        notifications.setAccessibilityIdentifier("Settings.Notifications")
        addSection("系统通知：", body: SettingsLayout.column([
            notifications, SettingsLayout.indent(notificationStatus)
        ], spacing: 4), firstControl: notifications)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshAuthorization),
                                               name: NSApplication.didBecomeActiveNotification, object: nil)
    }

    override func render() {
        soundEnabled.state = settings.soundEnabled ? .on : .off
        let soundControls: [NSControl] = [tone, preview, volume, playCount]
        soundControls.forEach { $0.isEnabled = settings.soundEnabled }
        volumeValue.textColor = settings.soundEnabled ? .labelColor : .disabledControlTextColor
        tone.selectItem(at: AppSettings.Tone.allCases.firstIndex(of: settings.tone) ?? 0)
        volume.doubleValue = settings.volume
        volumeValue.stringValue = "\(Int((settings.volume * 100).rounded()))%"
        playCount.selectItem(at: settings.playCount == 1 ? 0 : 1)
        notifications.isEnabled = !requestingPermission
        notifications.state = settings.notificationsEnabled ? .on : .off
        if requestingPermission { notificationStatus.stringValue = "请在系统提示中选择是否允许通知。" }
        else if permissionError { notificationStatus.stringValue = "无法开启通知。请稍后重试。" }
        else if status == .denied { notificationStatus.stringValue = "要接收通知，请在「系统设置」的「通知」中允许 AquaTimer 发送通知。" }
        else if status == .authorized || status == .provisional {
            notificationStatus.stringValue = "勾选后，AquaTimer 在后台计时结束时会发送通知。"
        } else { notificationStatus.stringValue = "开启后，macOS 会询问是否允许通知。" }
    }

    override func prepareForPresentation() { super.prepareForPresentation(); refreshAuthorization() }

    @objc private func refreshAuthorization() {
        guard !requestingPermission else { return }
        authorizationRevision += 1
        let revision = authorizationRevision
        Task { [weak self] in
            let current = await NotificationService.shared.authorizationStatus()
            guard let self, !requestingPermission, authorizationRevision == revision else { return }
            status = current
            if current != .authorized && current != .provisional { settings.notificationsEnabled = false }
            render()
        }
    }

    @objc private func changeNotifications(_ sender: NSButton) {
        authorizationRevision += 1
        permissionError = false
        if sender.state != .on { settings.notificationsEnabled = false; render(); return }
        requestingPermission = true
        render()
        Task { [weak self] in
            guard let self else { return }
            do { settings.notificationsEnabled = try await NotificationService.shared.requestPermission() }
            catch { settings.notificationsEnabled = false; permissionError = true }
            status = await NotificationService.shared.authorizationStatus()
            requestingPermission = false
            render()
        }
    }

    @objc private func changeSound(_ sender: NSButton) { settings.soundEnabled = sender.state == .on }
    @objc private func changeTone(_ sender: NSPopUpButton) { settings.tone = AppSettings.Tone.allCases[sender.indexOfSelectedItem] }
    @objc private func changeVolume(_ sender: NSSlider) { settings.volume = sender.doubleValue }
    @objc private func changePlayCount(_ sender: NSPopUpButton) { settings.playCount = sender.indexOfSelectedItem == 0 ? 1 : 3 }
    @objc private func previewSound(_ sender: Any?) {
        soundStatus.stringValue = CompletionSoundPlayer.shared.preview() ? Self.volumeHint : "无法试听这段提示音。请选择其他声音。"
    }
}
