import ApplicationServices
import AppKit
import CoreGraphics
import Foundation

enum PermissionState: Equatable {
    case unknown
    case granted
    case denied
    case notDetermined
    case restricted
}

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var accessibility: PermissionState = .unknown
    @Published private(set) var inputMonitoring: PermissionState = .unknown

    init() {
        refresh()
    }

    func refresh() {
        accessibility = AXIsProcessTrusted() ? .granted : .denied
        inputMonitoring = CGPreflightListenEventAccess() ? .granted : .denied
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func requestInputMonitoring() {
        let granted = CGRequestListenEventAccess()
        refresh()
        if !granted, inputMonitoring != .granted {
            openInputMonitoringSettings()
        }
    }

    func openAccessibilitySettings() {
        openSettings(anchor: "Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSettings(anchor: "Privacy_ListenEvent")
    }

    private func openSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
