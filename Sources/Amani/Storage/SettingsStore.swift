import Foundation

enum TriggerKind: String, CaseIterable {
    case hotkey
    case modifierHold
    case menuBar
}

final class SettingsStore {
    private let defaults: UserDefaults

    private static func enabledKey(_ kind: TriggerKind) -> String {
        "trigger.\(kind.rawValue).enabled"
    }
    private static let modifierHoldDurationKey = "trigger.modifierHold.durationSeconds"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isTriggerEnabled(_ kind: TriggerKind) -> Bool {
        if defaults.object(forKey: Self.enabledKey(kind)) == nil {
            return true // default: every trigger ships enabled
        }
        return defaults.bool(forKey: Self.enabledKey(kind))
    }

    func setTriggerEnabled(_ kind: TriggerKind, enabled: Bool) {
        defaults.set(enabled, forKey: Self.enabledKey(kind))
    }

    var modifierHoldDurationSeconds: Double {
        get {
            let value = defaults.double(forKey: Self.modifierHoldDurationKey)
            return value == 0 ? 5.0 : value
        }
        set {
            defaults.set(newValue, forKey: Self.modifierHoldDurationKey)
        }
    }
}
