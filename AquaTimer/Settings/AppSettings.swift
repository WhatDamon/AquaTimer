import Foundation

@MainActor
final class AppSettings {
    static let shared = AppSettings()
    static let didChange = Notification.Name("AquaTimer.SettingsChanged")

    enum StartupMode: String { case fixed, lastUsed }
    enum Tone: String, CaseIterable {
        case glass = "Glass", ping = "Ping", submarine = "Submarine"
        var title: String {
            switch self {
            case .glass: "玻璃音（Glass）"
            case .ping: "清脆提示（Ping）"
            case .submarine: "潜水提示（Submarine）"
            }
        }
    }

    private let defaults: UserDefaults
    private static func key(_ name: String) -> String { "AquaTimer.Settings." + name }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: Dictionary(uniqueKeysWithValues: [
            ("startupMode", "fixed" as Any), ("fixedDuration", 1500), ("lastDuration", 1500),
            ("rememberControlArea", false), ("lastCollapsed", false), ("confirmQuit", true),
            ("soundEnabled", true), ("tone", "Glass"), ("volume", 0.7),
            ("playCount", 3), ("notificationsEnabled", false), ("selectedPane", 0)
        ].map { (Self.key($0.0), $0.1) }))
    }

    var startupMode: StartupMode {
        get { StartupMode(rawValue: defaults.string(forKey: Self.key("startupMode")) ?? "") ?? .fixed }
        set { set(newValue.rawValue, "startupMode") }
    }
    var fixedDuration: Int {
        get { validDuration(defaults.integer(forKey: Self.key("fixedDuration"))) }
        set { if (1...86_399).contains(newValue) { set(newValue, "fixedDuration") } }
    }
    var initialDuration: Int {
        startupMode == .fixed ? fixedDuration : validDuration(defaults.integer(forKey: Self.key("lastDuration")))
    }
    var rememberControlArea: Bool {
        get { defaults.bool(forKey: Self.key("rememberControlArea")) }
        set { set(newValue, "rememberControlArea") }
    }
    var initialControlsCollapsed: Bool {
        rememberControlArea && defaults.bool(forKey: Self.key("lastCollapsed"))
    }
    var confirmQuit: Bool {
        get { defaults.bool(forKey: Self.key("confirmQuit")) }
        set { set(newValue, "confirmQuit") }
    }
    var soundEnabled: Bool {
        get { defaults.bool(forKey: Self.key("soundEnabled")) }
        set { set(newValue, "soundEnabled") }
    }
    var tone: Tone {
        get { Tone(rawValue: defaults.string(forKey: Self.key("tone")) ?? "") ?? .glass }
        set { set(newValue.rawValue, "tone") }
    }
    var volume: Double {
        get {
            let value = defaults.double(forKey: Self.key("volume"))
            return value.isFinite ? min(1, max(0, value)) : 0.7
        }
        set { if newValue.isFinite { set(min(1, max(0, newValue)), "volume") } }
    }
    var playCount: Int {
        get { defaults.integer(forKey: Self.key("playCount")) == 1 ? 1 : 3 }
        set { set(newValue == 1 ? 1 : 3, "playCount") }
    }
    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Self.key("notificationsEnabled")) }
        set { set(newValue, "notificationsEnabled") }
    }
    var selectedPane: Int {
        get { defaults.integer(forKey: Self.key("selectedPane")) == 1 ? 1 : 0 }
        set { defaults.set(newValue == 1 ? 1 : 0, forKey: Self.key("selectedPane")) }
    }

    func rememberDuration(_ seconds: Int) {
        guard (1...86_399).contains(seconds),
              seconds != defaults.integer(forKey: Self.key("lastDuration")) else { return }
        defaults.set(seconds, forKey: Self.key("lastDuration"))
    }

    func rememberControlsCollapsed(_ collapsed: Bool) {
        defaults.set(collapsed, forKey: Self.key("lastCollapsed"))
    }

    private func validDuration(_ value: Int) -> Int { (1...86_399).contains(value) ? value : 1500 }

    private func set(_ value: Any, _ name: String) {
        let key = Self.key(name)
        if let old = defaults.object(forKey: key) as? NSObject,
           let next = value as? NSObject, old.isEqual(next) { return }
        defaults.set(value, forKey: key)
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
