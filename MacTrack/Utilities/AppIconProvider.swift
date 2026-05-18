import AppKit

enum AppIconProvider {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forBundleIdentifier bundleIdentifier: String) -> NSImage? {
        let key = bundleIdentifier as NSString
        guard !bundleIdentifier.isEmpty else { return nil }
        if let cached = cache.object(forKey: key) {
            return cached
        }

        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
           let icon = running.icon {
            cache.setObject(icon, forKey: key)
            return icon
        }

        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            cache.setObject(icon, forKey: key)
            return icon
        }

        return nil
    }
}
