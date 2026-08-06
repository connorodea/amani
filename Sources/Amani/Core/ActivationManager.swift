import Foundation

@MainActor
final class ActivationManager {
    private let triggers: [ActivationTrigger]
    private let settings: SettingsStore
    private let onActivate: () -> Void

    init(triggers: [ActivationTrigger], settings: SettingsStore, onActivate: @escaping () -> Void) {
        self.triggers = triggers
        self.settings = settings
        self.onActivate = onActivate
    }

    func start() {
        for trigger in triggers {
            guard let kind = TriggerKind(rawValue: trigger.id) else { continue }
            guard settings.isTriggerEnabled(kind) else { continue }
            trigger.start { [onActivate] in onActivate() }
        }
    }

    func stop() {
        for trigger in triggers {
            trigger.stop()
        }
    }
}
