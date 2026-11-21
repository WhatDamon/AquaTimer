import AppKit

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var mainWindowController: MainWindowController?
    private var aboutWindowController: AboutWindowController?
    private var settingsWindowController: SettingsWindowController?
    private var isConfirmingQuit = false

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)

        withExtendedLifetime(delegate) {
            application.run()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ApplicationMenu.install()
        showMainWindow()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showMainWindow()
        return true
    }

    private func showMainWindow() {
        if mainWindowController == nil {
            mainWindowController = MainWindowController()
        }
        mainWindowController?.showWindow(nil)
    }

    @objc func showAboutWindow(_ sender: Any?) {
        if aboutWindowController == nil { aboutWindowController = AboutWindowController() }
        aboutWindowController?.showWindow(sender)
    }

    @objc func showSettingsWindow(_ sender: Any?) {
        if settingsWindowController == nil { settingsWindowController = SettingsWindowController() }
        settingsWindowController?.showWindow(sender)
    }

    @objc func stopTimerAlert(_ sender: Any?) { mainWindowController?.stopTimerAlert() }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(stopTimerAlert(_:)) {
            return mainWindowController?.canStopTimerAlert == true
        }
        return true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard !isConfirmingQuit else { return .terminateCancel }
        guard AppSettings.shared.confirmQuit, mainWindowController?.hasActiveCountdown == true else {
            return .terminateNow
        }
        isConfirmingQuit = true
        defer { isConfirmingQuit = false }
        return QuitConfirmationPanel().confirm(in: sender) ? .terminateNow : .terminateCancel
    }
}

