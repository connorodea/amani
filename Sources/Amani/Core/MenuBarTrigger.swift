import AppKit

@MainActor
final class MenuBarTrigger: ActivationTrigger {
    let id = TriggerKind.menuBar.rawValue

    private var statusItem: NSStatusItem?
    private var onActivate: (() -> Void)?

    func start(onActivate: @escaping () -> Void) {
        self.onActivate = onActivate
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "circle.hexagongrid.circle", accessibilityDescription: "Amani")
        item.button?.target = self
        item.button?.action = #selector(handleClick)
        statusItem = item
    }

    func stop() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        onActivate = nil
    }

    /// Test-only hook — real clicks arrive via `handleClick` from AppKit, which XCTest can't
    /// synthesize for a real NSStatusItem button reliably, so tests call this directly instead.
    func simulateClickForTesting() {
        handleClick()
    }

    @objc private func handleClick() {
        onActivate?()
    }
}
