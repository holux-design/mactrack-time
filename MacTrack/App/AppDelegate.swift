import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            MacTrackAppContext.bootstrapTracking()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        DockVisibility.sync()
    }
}
