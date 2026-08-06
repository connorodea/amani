import AppKit
import SwiftUI

/// A borderless `.nonactivatingPanel` returns NO from `canBecomeKeyWindow` by default —
/// confirmed via Console: "-[NSWindow makeKeyWindow] called on <NSPanel> which returned NO
/// from -[NSWindow canBecomeKeyWindow]." Without overriding this, the panel can display but
/// can never actually receive keyboard input, so the search field is untypable. Overriding
/// `canBecomeKey`/`canBecomeMain` fixes that while `.nonactivatingPanel` still does its other
/// job of not stealing focus from other apps at the moment the panel is *ordered* front.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private enum KeyCode {
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
    static let returnKey: UInt16 = 36
    static let numpadEnter: UInt16 = 76
    static let escape: UInt16 = 53
}

@MainActor
final class OverlayWindowController {
    private(set) var isVisible = false
    private var panel: NSPanel?
    private let searchController: SearchController
    private var keyMonitor: Any?
    private var onSubmitSelected: (() -> Void)?
    // Bumped on every show()/hide(); a hide()'s animation completion handler only calls
    // orderOut(nil) if this still matches the generation it captured. Without this, a rapid
    // hide() followed by a show() (double-tapping the toggle hotkey) races: the stale hide's
    // completion handler fires after the new show() already made the panel visible again, and
    // yanks it back off-screen — the panel then needs a 3rd toggle to reappear, since isVisible
    // is left reading `true` while the window is actually hidden.
    private var animationGeneration = 0

    init(searchController: SearchController? = nil) {
        self.searchController = searchController ?? SearchController(providers: [])
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        guard !isVisible else { return }
        animationGeneration += 1
        let panel = self.panel ?? makePanel()
        self.panel = panel
        positionCentered(panel)
        // The panel/NSHostingView/SwiftUI view are created once and reused across every
        // show()/hide() cycle, so SwiftUI's `.onAppear` (which only fires once per view
        // lifetime) can't be relied on to refocus the search field after the first open —
        // confirmed by review: after open→close→reopen, `.onAppear` never fires again and
        // nothing else calls back into first-responder. `recordActivation()` gives the view an
        // explicit signal on every show(), not just the first.
        searchController.recordActivation()
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
        installKeyMonitor()
    }

    func hide() {
        guard isVisible, let panel else {
            isVisible = false
            return
        }
        animationGeneration += 1
        let generationAtHide = animationGeneration
        let shrunkFrame = Self.scaledFrame(panel.frame, by: 0.96)
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(shrunkFrame, display: true)
        }, completionHandler: { [weak self] in
            // Only order out if no newer show()/hide() has superseded this one — otherwise a
            // rapid re-show() that happened while this animation was still in flight would get
            // yanked back off-screen by this now-stale completion. See `animationGeneration`.
            guard self?.animationGeneration == generationAtHide else { return }
            panel.orderOut(nil)
        })
        searchController.query = ""
        isVisible = false
        removeKeyMonitor()
    }

    /// Arrow/return/escape navigation is handled here — via a local `NSEvent` monitor — rather
    /// than SwiftUI's `.onKeyPress`, which was found (via a Console-log-confirmed regression) to
    /// swallow ordinary character keystrokes before they reached the search field's own field
    /// editor on this SwiftUI/AppKit combination. A monitor scoped to only these four key codes,
    /// which returns the event untouched for everything else, can't have that failure mode.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case KeyCode.downArrow:
                searchController.moveSelection(by: 1)
                return nil
            case KeyCode.upArrow:
                searchController.moveSelection(by: -1)
                return nil
            case KeyCode.returnKey, KeyCode.numpadEnter:
                if searchController.selectedResult != nil {
                    onSubmitSelected?()
                }
                return nil
            case KeyCode.escape:
                hide()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
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
        let submit: (SearchResult) -> Void = { [weak self] result in
            ActionExecutor.perform(result.action)
            self?.hide()
        }
        onSubmitSelected = { [weak self] in
            guard let self, let selected = searchController.selectedResult else { return }
            submit(selected)
        }
        let hostingView = NSHostingView(
            rootView: SearchView(searchController: searchController, onSubmit: submit)
        )
        // Borderless, not `.titled` — `.titled` (even with titleVisibility hidden) leaves a
        // visible native titlebar strip and window-chrome border, confirmed by direct visual
        // inspection on real hardware. `.borderless` + `.nonactivatingPanel` is the standard
        // recipe for a true chromeless Spotlight/Alfred-style overlay.
        let panel = OverlayPanel(
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
