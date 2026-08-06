import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    private(set) var isVisible = false
    private var panel: NSPanel?
    private let searchController: SearchController

    init(searchController: SearchController? = nil) {
        self.searchController = searchController ?? SearchController(providers: [])
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        guard !isVisible else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        positionCentered(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }

    func hide() {
        guard isVisible, let panel else {
            isVisible = false
            return
        }
        panel.orderOut(nil)
        searchController.query = ""
        isVisible = false
    }

    private func makePanel() -> NSPanel {
        let hostingView = NSHostingView(
            rootView: SearchView(
                searchController: searchController,
                onSubmit: { [weak self] result in
                    ActionExecutor.perform(result.action)
                    self?.hide()
                }
            )
        )
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 80),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hasShadow = true
        panel.contentView = hostingView
        panel.isReleasedWhenClosed = false
        return panel
    }

    private func positionCentered(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.maxY - screenFrame.height * 0.3 - panelSize.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

enum ActionExecutor {
    static func perform(_ action: SearchResultAction) {
        switch action {
        case .launchApp(let bundleURL):
            NSWorkspace.shared.open(bundleURL)
        case .openFile(let path):
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        case .copyToClipboard(let text):
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }
}
