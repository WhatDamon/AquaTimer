import AppKit

@MainActor
final class TimerViewController: NSViewController, NSTextFieldDelegate {
    private let timerView = TimerView()
    private let clock = ContinuousClock()
    private let origin = ContinuousClock().now
    private var countdown = Countdown()
    private var refreshTimer: Timer?
    private var attentionRequest: Int?
    private var activity: NSObjectProtocol?
    private let inputHistory: DurationInputHistory
    private var validationRequested = false

    init() {
        let seconds = AppSettings.shared.initialDuration
        let values = DurationInputValues(hours: String(seconds / 3600), minutes: String(seconds / 60 % 60),
                                         seconds: String(seconds % 60))
        inputHistory = DurationInputHistory(initial: values)
        super.init(nibName: nil, bundle: nil)
        for (field, value) in zip(timerView.durationFields, values.components) { field.stringValue = value }
    }

    override func loadView() {
        view = timerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        inputHistory.didRestore = { [weak self] values in
            guard let self else { return }
            for (field, value) in zip(timerView.durationFields, values.components) { field.stringValue = value }
            validationRequested = true
            durationDidChange()
        }
        for field in timerView.durationFields {
            field.delegate = self
            field.target = self
            field.action = #selector(performPrimaryAction(_:))
            field.cell?.sendsActionOnEndEditing = false
        }
        timerView.primaryButton.target = self
        timerView.primaryButton.action = #selector(performPrimaryAction(_:))
        timerView.resetButton.target = self
        timerView.resetButton.action = #selector(resetTimer(_:))
        timerView.minuteDial.target = self
        timerView.minuteDial.action = #selector(adjustMinutes(_:))
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refresh(_:)), name: NSWorkspace.didWakeNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh(_:)), name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        render()
    }

    private var elapsedTime: TimeInterval {
        let elapsed = origin.duration(to: clock.now).components
        return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
    }

    private var selectedSeconds: Int? {
        CountdownDuration.seconds(
            hours: timerView.hoursField.stringValue,
            minutes: timerView.minutesField.stringValue,
            seconds: timerView.secondsField.stringValue
        )
    }

    private var inputValues: DurationInputValues {
        DurationInputValues(hours: timerView.hoursField.stringValue,
                            minutes: timerView.minutesField.stringValue, seconds: timerView.secondsField.stringValue)
    }

    private var canEditDuration: Bool { countdown.state == .idle || countdown.state == .finished }
    var canUndoDurationEdit: Bool { canEditDuration && inputHistory.undoManager.canUndo }
    var canRedoDurationEdit: Bool { canEditDuration && inputHistory.undoManager.canRedo }

    func undoDurationEdit() {
        guard canUndoDurationEdit else { return }
        let before = inputValues
        view.window?.makeFirstResponder(nil)
        inputHistory.undo()
        focusRestoredValues(from: before)
    }

    func redoDurationEdit() {
        guard canRedoDurationEdit else { return }
        let before = inputValues
        view.window?.makeFirstResponder(nil)
        inputHistory.redo()
        focusRestoredValues(from: before)
    }

    private func focusRestoredValues(from before: DurationInputValues) {
        let index = zip(before.components, inputValues.components).enumerated()
            .first(where: { $0.element.0 != $0.element.1 })?.offset ?? 1
        let field = timerView.durationFields[index]
        if !field.isHiddenOrHasHiddenAncestor { field.selectText(nil) }
    }

    var compactHeight: CGFloat { timerView.compactHeight }
    var expandedHeight: CGFloat { timerView.expandedHeight }
    var primaryActionTitle: String { timerView.primaryButton.title }
    var canPerformPrimaryAction: Bool { timerView.primaryButton.isEnabled }
    var canResetTimer: Bool { timerView.resetButton.isEnabled }
    var hasActiveCountdown: Bool { countdown.state == .running || countdown.state == .paused }
    var canStopTimerAlert: Bool { CompletionSoundPlayer.shared.isPlaying }

    func stopTimerAlert() {
        CompletionSoundPlayer.shared.stop()
        if let attentionRequest {
            NSApp.cancelUserAttentionRequest(attentionRequest)
            self.attentionRequest = nil
        }
    }

    func preferredFirstResponder(controlsCollapsed: Bool) -> NSView? {
        if controlsCollapsed { return nil }
        return timerView.minutesField.isEnabled ? timerView.minutesField : timerView.primaryButton
    }

    func focusControls(controlsCollapsed: Bool) {
        let responder = preferredFirstResponder(controlsCollapsed: controlsCollapsed)
        guard view.window?.makeFirstResponder(responder) == true else { return }
        if let field = responder as? NSTextField, field.isEditable { field.selectText(nil) }
    }

    func prepareToCollapse() -> Bool {
        guard view.window?.makeFirstResponder(nil) != false else { return false }
        guard countdown.state == .idle || countdown.state == .finished else { return true }
        guard selectedSeconds != nil else {
            validationRequested = true
            render()
            let field = timerView.durationFields[inputValues.issue?.fieldIndex ?? 1]
            view.window?.makeFirstResponder(field)
            field.selectText(nil)
            NSSound.beep()
            return false
        }
        return true
    }

    func setControlsCollapsed(_ collapsed: Bool) {
        timerView.setControlsCollapsed(collapsed)
    }

    @objc func performPrimaryAction(_ sender: Any?) {
        view.window?.makeFirstResponder(nil)
        let previousState = countdown.state
        let now = elapsedTime
        switch countdown.state {
        case .idle, .finished:
            validationRequested = true
            guard let seconds = selectedSeconds else {
                render()
                let field = timerView.durationFields[inputValues.issue?.fieldIndex ?? 1]
                field.selectText(nil)
                return
            }
            clearCompletion()
            AppSettings.shared.rememberDuration(seconds)
            countdown.start(seconds: seconds, at: now)
        case .running:
            countdown.pause(at: now)
        case .paused:
            countdown.resume(at: now)
        }
        reconcile(previousState: previousState)
    }

    @objc func resetTimer(_ sender: Any?) {
        countdown.reset()
        clearCompletion()
        reconcile(previousState: .idle)
    }

    @objc private func refresh(_ sender: Any?) {
        let previousState = countdown.state
        countdown.update(at: elapsedTime)
        reconcile(previousState: previousState)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard canEditDuration else { return }
        inputHistory.record(inputValues, field: obj.object as? NSTextField)
        validationRequested = false
        durationDidChange()
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard canEditDuration else { return }
        inputHistory.record(inputValues, field: obj.object as? NSTextField)
        inputHistory.endCoalescing()
        validationRequested = true
        render()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertNewline(_:)), !textView.hasMarkedText() else { return false }
        performPrimaryAction(control)
        return true
    }

    @objc private func adjustMinutes(_ sender: NSSlider) {
        guard countdown.state == .idle || countdown.state == .finished else { return }
        view.window?.makeFirstResponder(sender)
        timerView.minutesField.integerValue = Int(sender.doubleValue.rounded())
        inputHistory.record(inputValues)
        validationRequested = true
        durationDidChange()
    }

    private func durationDidChange() {
        if let seconds = selectedSeconds { AppSettings.shared.rememberDuration(seconds) }
        if countdown.state == .finished {
            countdown.reset()
            clearCompletion()
        }
        render()
    }

    private func reconcile(previousState: Countdown.State) {
        if countdown.state == .running {
            if activity == nil {
                activity = ProcessInfo.processInfo.beginActivity(
                    options: .userInitiatedAllowingIdleSystemSleep,
                    reason: "A countdown is running."
                )
            }
            if refreshTimer == nil {
                let timer = Timer(timeInterval: 0.1, target: self, selector: #selector(refresh(_:)),
                                  userInfo: nil, repeats: true)
                timer.tolerance = 0.05
                RunLoop.main.add(timer, forMode: .common)
                refreshTimer = timer
            }
        } else {
            refreshTimer?.invalidate()
            refreshTimer = nil
            if let activity {
                ProcessInfo.processInfo.endActivity(activity)
                self.activity = nil
            }
        }
        render()
        if previousState != .finished && countdown.state == .finished {
            CompletionSoundPlayer.shared.playCompletion()
            NotificationService.shared.postCompletionIfNeeded()
            NSApp.dockTile.badgeLabel = "时间到"
            if !NSApp.isActive {
                attentionRequest = NSApp.requestUserAttention(.informationalRequest)
            }
            NSAccessibility.post(
                element: timerView, notification: .announcementRequested,
                userInfo: [.announcement: "计时结束，时间到。",
                           .priority: NSAccessibilityPriorityLevel.high.rawValue]
            )
        }
    }

    private func clearCompletion() {
        CompletionSoundPlayer.shared.stop()
        NotificationService.shared.cancelCompletion()
        NSApp.dockTile.badgeLabel = nil
        if let attentionRequest {
            NSApp.cancelUserAttentionRequest(attentionRequest)
            self.attentionRequest = nil
        }
    }

    private func render() {
        let canEdit = canEditDuration
        let seconds = selectedSeconds
        timerView.durationFields.forEach { $0.isEnabled = canEdit }
        timerView.minuteDial.isEnabled = canEdit
        let minutes = Int(timerView.minutesField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        timerView.minuteDial.integerValue = min(59, max(0, minutes))
        let issue = canEdit && validationRequested ? inputValues.issue : nil
        timerView.validationLabel.stringValue = issue?.message ?? ""
        timerView.validationLabel.setAccessibilityHidden(issue == nil)
        for (index, field) in timerView.durationFields.enumerated() {
            field.setAccessibilityHelp(issue?.fieldIndex == index ? issue?.message : nil)
        }
        timerView.primaryButton.isEnabled = !canEdit || seconds != nil
        timerView.resetButton.isEnabled = countdown.state != .idle
        timerView.display.progressIndicator.doubleValue = countdown.state == .idle || countdown.duration == 0
            ? 0 : (countdown.duration - countdown.remaining) / countdown.duration

        if countdown.state == .idle {
            timerView.display.showTime(seconds.map { Double($0) })
        } else {
            timerView.display.showTime(countdown.remaining)
        }

        switch countdown.state {
        case .idle:
            timerView.primaryButton.title = "开始"
            timerView.primaryButton.icon = .play
        case .running:
            timerView.primaryButton.title = "暂停"
            timerView.primaryButton.icon = .pause
        case .paused:
            timerView.primaryButton.title = "继续"
            timerView.primaryButton.icon = .play
        case .finished:
            timerView.primaryButton.title = "再次开始"
            timerView.primaryButton.icon = .reset
        }
        timerView.display.updateAppearance(for: countdown.state)
        view.window?.title = countdown.state == .finished ? "时间到 — AquaTimer" : "AquaTimer"
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TimerViewController uses programmatic initialization.")
    }
}
