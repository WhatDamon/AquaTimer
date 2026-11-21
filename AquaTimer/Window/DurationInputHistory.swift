import AppKit

struct DurationInputValues: Equatable {
    let hours: String
    let minutes: String
    let seconds: String

    var components: [String] { [hours, minutes, seconds] }

    struct Issue {
        let fieldIndex: Int?
        let message: String
    }

    var issue: Issue? {
        guard CountdownDuration.seconds(hours: hours, minutes: minutes, seconds: seconds) == nil else { return nil }
        for (index, item) in zip(components, [("小时", 0...23), ("分钟", 0...59), ("秒", 0...59)]).enumerated() {
            let value = item.0.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty || !value.utf8.allSatisfy({ (48...57).contains($0) })
                || Int(value).map({ item.1.1.contains($0) }) != true {
                return Issue(fieldIndex: index, message: "\(item.1.0)请输入 \(item.1.1.lowerBound)–\(item.1.1.upperBound) 的整数")
            }
        }
        return Issue(fieldIndex: nil, message: "时长至少为 1 秒")
    }
}

/// Coalesce a field-editing session while preserving undo across field changes and dial edits.
@MainActor
final class DurationInputHistory {
    let undoManager = UndoManager()
    var didRestore: ((DurationInputValues) -> Void)?
    private(set) var current: DurationInputValues
    private var coalescingField: ObjectIdentifier?

    init(initial: DurationInputValues) {
        current = initial
        undoManager.groupsByEvent = false
        undoManager.levelsOfUndo = 50
    }

    func record(_ values: DurationInputValues, field: NSTextField? = nil) {
        guard values != current else { return }
        let key = field.map(ObjectIdentifier.init)
        if key == nil || key != coalescingField {
            register(current)
        }
        current = values
        coalescingField = key
    }

    func endCoalescing() { coalescingField = nil }

    func undo() {
        endCoalescing()
        undoManager.undo()
    }

    func redo() {
        endCoalescing()
        undoManager.redo()
    }

    private func register(_ values: DurationInputValues) {
        let grouping = !undoManager.isUndoing && !undoManager.isRedoing
        if grouping { undoManager.beginUndoGrouping() }
        undoManager.registerUndo(withTarget: self) { history in
            history.restore(values)
        }
        undoManager.setActionName("编辑时长" as String)
        if grouping { undoManager.endUndoGrouping() }
    }

    private func restore(_ values: DurationInputValues) {
        register(current)
        current = values
        endCoalescing()
        didRestore?(values)
    }
}
