import AppKit

enum DockVisibility {
    private static var mainWindowCount = 0

    static var hasMainWindow: Bool { mainWindowCount > 0 }

    static func mainWindowDidOpen() {
        mainWindowCount += 1
        applyPolicy()
    }

    static func mainWindowDidClose() {
        mainWindowCount = max(0, mainWindowCount - 1)
        applyPolicy()
    }

    static func sync() {
        applyPolicy()
    }

    static func restoreAccessoryIfNeeded() {
        guard !hasMainWindow else { return }
        applyPolicy()
    }

    private static func applyPolicy() {
        let policy: NSApplication.ActivationPolicy = hasMainWindow ? .regular : .accessory

        if policy == .regular {
            NSApp.applicationIconImage = DockIconImage.shared
        }

        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
    }
}
