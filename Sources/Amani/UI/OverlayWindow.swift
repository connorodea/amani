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
        // Activate the app BEFORE ordering the panel front. Calling activate() after
        // orderFront() lets the OS order the panel front while Amani is still a background
        // (non-active) app, which stacks it beneath whatever app is actually frontmost —
        // confirmed via Console: "Window ... ordered front from a non-active application
        // and may order beneath the active application's windows."
        NSApp.activate(ignoringOtherApps: true)

        // Fade + scale in from a slightly-smaller, slightly-lower starting point, rather than
        // an abrupt pop — a small but real perceived-quality difference for a launcher that's
        // summoned constantly.
        panel.alphaValue = 0
        let targetFrame = panel.frame
        panel.setFrame(Self.scaledFrame(targetFrame, by: 0.96), display: false)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        }
        isVisible = true
    }

    func hide() {
        guard isVisible, let panel else {
            isVisible = false
            return
        }
        let shrunkFrame = Self.scaledFrame(panel.frame, by: 0.96)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(shrunkFrame, display: true)
        }, completionHandler: {
            panel.orderOut(nil)
        })
        searchController.query = ""
        isVisible = false
    }

    private static func scaledFrame(_ frame: NSRect, by factor: CGFloat) -> NSRect {
        let newSize = NSSize(width: frame.width * factor, height: frame.height * factor)
        let origin = NSPoint(
            x: frame.midX - newSize.width / 2,
            y: frame.midY - newSize.height / 2
        )
        return NSRect(origin: origin, size: newSize)
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
        // Borderless, not `.titled` — `.titled` (even with titleVisibility hidden) leaves a
        // visible native titlebar strip and window-chrome border, confirmed by direct visual
        // inspection on real hardware. `.borderless` + `.nonactivatingPanel` is the standard
        // recipe for a true chromeless Spotlight/Alfred-style overlay.
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        // Required for SwiftUI's translucent materials (.regularMaterial) to actually blur
        // the desktop behind the panel instead of rendering as a flat opaque fill.
        panel.isOpaque = false
        panel.backgroundColor = .clear
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
