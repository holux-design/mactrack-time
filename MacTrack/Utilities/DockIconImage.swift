import AppKit

enum DockIconImage {
    /// Uses the bundled app icon (margin and shape are baked into AppIcon assets).
    static let shared: NSImage? = loadSource()

    private static func loadSource() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let image = Bundle.main.image(forResource: NSImage.Name("AppIcon")) {
            return image
        }
        return NSImage(named: "AppIcon")
    }
}
