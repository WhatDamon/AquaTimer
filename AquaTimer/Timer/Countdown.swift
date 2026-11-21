import Foundation

struct Countdown {
    enum State {
        case idle, running, paused, finished
    }

    private(set) var state: State = .idle
    private(set) var duration: TimeInterval = 0
    private(set) var remaining: TimeInterval = 0
    private var deadline: TimeInterval?

    mutating func start(seconds: Int, at now: TimeInterval) {
        guard state == .idle || state == .finished,
              (1...86_399).contains(seconds), now.isFinite else { return }
        duration = TimeInterval(seconds)
        remaining = duration
        deadline = now + duration
        state = .running
    }

    mutating func update(at now: TimeInterval) {
        guard state == .running, let deadline, now.isFinite else { return }
        remaining = max(0, min(duration, deadline - now))
        if remaining == 0 {
            self.deadline = nil
            state = .finished
        }
    }

    mutating func pause(at now: TimeInterval) {
        guard state == .running, now.isFinite else { return }
        update(at: now)
        guard state == .running else { return }
        deadline = nil
        state = .paused
    }

    mutating func resume(at now: TimeInterval) {
        guard state == .paused, now.isFinite else { return }
        deadline = now + remaining
        state = .running
    }

    mutating func reset() {
        deadline = nil
        remaining = duration
        state = .idle
    }
}
