import AppKit

@MainActor
final class CompletionSoundPlayer {
    static let shared = CompletionSoundPlayer()
    private let settings: AppSettings
    private var sound: NSSound?
    private var previewSound: NSSound?
    private var playback: Task<Void, Never>?
    private var sequence: UUID?
    var isPlaying: Bool { playback != nil }

    init(settings: AppSettings = .shared) {
        self.settings = settings
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: AppSettings.didChange, object: settings)
    }

    func playCompletion() {
        stop()
        stopPreview()
        guard settings.soundEnabled else { return }
        let id = UUID()
        sequence = id
        let count = settings.playCount
        let tone = settings.tone
        playback = Task { [weak self] in
            guard let self else { return }
            defer {
                if sequence == id { sound = nil; playback = nil; sequence = nil }
            }
            for index in 0..<count {
                guard !Task.isCancelled, sequence == id, settings.soundEnabled,
                      let next = makeSound(tone: tone) else { return }
                sound = next
                guard next.play() else { return }
                do {
                    let gap = index < count - 1 ? 0.4 : 0
                    try await Task.sleep(for: .seconds(max(0.05, next.duration) + gap))
                } catch { return }
            }
        }
    }

    @discardableResult
    func preview() -> Bool {
        stopPreview()
        guard settings.soundEnabled, let next = makeSound(tone: settings.tone) else { return false }
        previewSound = next
        return next.play()
    }

    func stopPreview() { previewSound?.stop(); previewSound = nil }

    func stop() {
        sequence = nil
        playback?.cancel()
        playback = nil
        sound?.stop()
        sound = nil
    }

    private func makeSound(tone: AppSettings.Tone) -> NSSound? {
        guard let original = NSSound(named: NSSound.Name(tone.rawValue)),
              let copy = original.copy() as? NSSound else { return nil }
        copy.volume = Float(settings.volume)
        return copy
    }

    @objc private func settingsChanged() {
        if !settings.soundEnabled { stop(); stopPreview() }
        sound?.volume = Float(settings.volume)
        previewSound?.volume = Float(settings.volume)
    }
}
