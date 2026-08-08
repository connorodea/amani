import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appModel: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let model = AppModel()
        appModel = model
        model.start()
        model.showSetupWindowIfNeeded()
    }
}
