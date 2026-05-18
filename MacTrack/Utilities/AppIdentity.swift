import Foundation

enum AppIdentity {
    static let displayName = "Mactrack Time"

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.example.MactrackTime"
    }

    static func isSelfApp(bundleIdentifier: String) -> Bool {
        let id = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return false }
        return id == Self.bundleIdentifier
    }
}
