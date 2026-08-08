import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppModel {
    let settings: SettingsStore
    let permissionManager: PermissionManager
    let setupAssistant: SetupAssistant
    let searchController: SearchController
    let overlayWindowController: OverlayWindowController
    let activationManager: ActivationManager

    private var setupWindow: NSWindow?

    init(settings: SettingsStore = SettingsStore()) {
        self.settings = settings
        self.permissionManager = PermissionManager()
        self.setupAssistant = SetupAssistant(permissionManager: permissionManager, settings: settings)

        let providers: [ResultProvider] = [
            CalculatorProvider(),
            AppLauncherProvider(),
            FileSearchProvider(),
        ]
        let searchController = SearchController(providers: providers)
        self.searchController = searchController

        let overlayWindowController = OverlayWindowController(searchController: searchController)
        self.overlayWindowController = overlayWindowController

        let triggers: [ActivationTrigger] = [
            HotkeyTrigger(),
            ModifierHoldTrigger(thresholdSeconds: settings.modifierHoldDurationSeconds),
            MenuBarTrigger(),
        ]
        self.activationManager = ActivationManager(
            triggers: triggers,
            settings: settings,
            onActivate: { [overlayWindowController] in overlayWindowController.toggle() }
        )
    }

    func start() {
        activationManager.start()
    }

    /// Test-only convenience — exercises the same path a real trigger firing would.
    func activateOverlayForTesting() {
        overlayWindowController.toggle()
    }

    /// Presents `SetupView` in a real window whenever a required permission isn't granted yet —
    /// otherwise the user has no in-app path to discover why `HotkeyTrigger`/`ModifierHoldTrigger`
    /// silently failed to start (they fail-safe rather than crash, per Tasks 9-10).
    func showSetupWindowIfNeeded() {
        guard permissionManager.accessibility != .granted || permissionManager.inputMonitoring != .granted else {
            return
        }
        if let setupWindow {
            setupWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(
            rootView: SetupView(
                setupAssistant: setupAssistant,
                permissionManager: permissionManager,
                restartTriggers: { [activationManager] in activationManager.start() }
            )
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Amani Setup"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        setupWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
