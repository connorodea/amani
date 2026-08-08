import SwiftUI

struct SetupView: View {
    @ObservedObject var setupAssistant: SetupAssistant
    @ObservedObject var permissionManager: PermissionManager
    /// `ModifierHoldTrigger.start()` silently no-ops if Input Monitoring isn't granted yet at
    /// launch — refreshing permission state alone doesn't retry it. This restarts every enabled
    /// trigger (harmless for ones already running; each trigger's own `start()` is idempotent).
    let restartTriggers: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to Amani").font(.title2).bold()

            permissionRow(
                title: "Accessibility",
                state: permissionManager.accessibility,
                grant: { permissionManager.requestAccessibility() }
            )
            permissionRow(
                title: "Input Monitoring",
                state: permissionManager.inputMonitoring,
                grant: { permissionManager.requestInputMonitoring() }
            )

            if setupAssistant.isSpotlightBindingStillActive {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Spotlight still owns Cmd+Space").font(.headline)
                    Text("Disable it in Keyboard Shortcuts so Amani can take over.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Keyboard Shortcuts…") {
                        setupAssistant.openKeyboardShortcutsSettings()
                    }
                }
            }

            Button("I've granted permissions — refresh") {
                permissionManager.refresh()
                setupAssistant.refreshSpotlightBindingState()
                restartTriggers()
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func permissionRow(title: String, state: PermissionState, grant: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
            Spacer()
            switch state {
            case .granted:
                Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            default:
                Button("Grant…", action: grant)
            }
        }
    }
}
