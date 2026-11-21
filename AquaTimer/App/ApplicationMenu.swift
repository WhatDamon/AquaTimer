import AppKit

@MainActor
enum ApplicationMenu {
    static func install() {
        let mainMenu = NSMenu()
        let applicationMenu = NSMenu(title: "AquaTimer")
        applicationMenu.addItem(withTitle: "关于 AquaTimer",
                                action: #selector(AppDelegate.showAboutWindow(_:)),
                                keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "偏好设置…",
                                action: #selector(AppDelegate.showSettingsWindow(_:)), keyEquivalent: ",")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "隐藏 AquaTimer",
                                action: #selector(NSApplication.hide(_:)),
                                keyEquivalent: "h")
        let hideOthers = applicationMenu.addItem(
            withTitle: "隐藏其他",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        applicationMenu.addItem(withTitle: "显示全部",
                                action: #selector(NSApplication.unhideAllApplications(_:)),
                                keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "退出 AquaTimer",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q")
        mainMenu.addItem(withTitle: "AquaTimer", action: nil, keyEquivalent: "")
            .submenu = applicationMenu

        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: #selector(AquaWindow.undoDurationEdit(_:)), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "重做", action: #selector(AquaWindow.redoDurationEdit(_:)), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "复制", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(withTitle: "编辑", action: nil, keyEquivalent: "").submenu = editMenu

        let viewMenu = NSMenu(title: "显示")
        let toolbarToggle = viewMenu.addItem(withTitle: "隐藏工具栏",
                                             action: #selector(SettingsWindow.toggleSettingsToolbar(_:)),
                                             keyEquivalent: "t")
        toolbarToggle.keyEquivalentModifierMask = [.option, .command]
        mainMenu.addItem(withTitle: "显示", action: nil, keyEquivalent: "").submenu = viewMenu

        let timerMenu = NSMenu(title: "计时器")
        let primaryAction = timerMenu.addItem(withTitle: "开始",
                                              action: #selector(AquaWindow.performTimerPrimaryAction(_:)),
                                              keyEquivalent: "\r")
        primaryAction.keyEquivalentModifierMask = []
        timerMenu.addItem(withTitle: "重置", action: #selector(AquaWindow.resetTimer(_:)), keyEquivalent: "r")
        let stopAlert = timerMenu.addItem(withTitle: "停止提醒", action: #selector(AppDelegate.stopTimerAlert(_:)), keyEquivalent: "")
        stopAlert.target = NSApp.delegate
        timerMenu.addItem(.separator())
        timerMenu.addItem(withTitle: "收起控制区域", action: #selector(AquaWindow.toggleControlArea(_:)),
                          keyEquivalent: "")
        mainMenu.addItem(withTitle: "计时器", action: nil, keyEquivalent: "").submenu = timerMenu

        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(withTitle: "最小化",
                           action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "关闭窗口",
                           action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "前置全部窗口",
                           action: #selector(NSApplication.arrangeInFront(_:)),
                           keyEquivalent: "")
        mainMenu.addItem(withTitle: "窗口", action: nil, keyEquivalent: "")
            .submenu = windowMenu

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }
}

