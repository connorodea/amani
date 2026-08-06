import Foundation
import AppKit

/// Detects whether macOS Spotlight still owns Cmd+Space, so the setup flow can tell the user
/// to disable it. Best-effort: reads the Symbolic HotKeys plist; if it can't be read/parsed,
/// assumes Spotlight may still be bound (safer default — nudge the user rather than stay silent).
enum SpotlightBindingChecker {
    private static let symbolicHotKeysPath = "\(NSHomeDirectory())/Library/Preferences/com.apple.symbolichotkeys.plist"
    private static let spotlightSearchHotKeyID = "64" // AppleSymbolicHotKeys key for "Show Spotlight search"

    static func spotlightMayStillOwnCmdSpace() -> Bool {
        guard let plistData = FileManager.default.contents(atPath: symbolicHotKeysPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let hotKeys = plist["AppleSymbolicHotKeys"] as? [String: Any],
              let entry = hotKeys[spotlightSearchHotKeyID] as? [String: Any],
              let enabled = entry["enabled"] as? Bool
        else {
            return true // can't determine — assume yes, nudge the user
        }
        return enabled
    }
}

@MainActor
final class SetupAssistant: ObservableObject {
    @Published var isSpotlightBindingStillActive: Bool

    let permissionManager: PermissionManager
    let settings: SettingsStore

    init(permissionManager: PermissionManager, settings: SettingsStore) {
        self.permissionManager = permissionManager
        self.settings = settings
        self.isSpotlightBindingStillActive = SpotlightBindingChecker.spotlightMayStillOwnCmdSpace()
    }

    func refreshSpotlightBindingState() {
        isSpotlightBindingStillActive = SpotlightBindingChecker.spotlightMayStillOwnCmdSpace()
    }

    func openKeyboardShortcutsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts") else { return }
        NSWorkspace.shared.open(url)
    }
}
