import Foundation

enum CountdownDuration {
    static func seconds(hours: String, minutes: String, seconds: String) -> Int? {
        guard let hours = component(hours, range: 0...23),
              let minutes = component(minutes, range: 0...59),
              let seconds = component(seconds, range: 0...59) else { return nil }
        let total = hours * 3_600 + minutes * 60 + seconds
        return total > 0 ? total : nil
    }

    static func display(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "--:--" }
        let total = Int(ceil(max(0, min(86_399, seconds))))
        let hours = total / 3_600
        let minutes = total / 60 % 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private static func component(_ text: String, range: ClosedRange<Int>) -> Int? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }),
              let value = Int(text), range.contains(value) else { return nil }
        return value
    }
}
