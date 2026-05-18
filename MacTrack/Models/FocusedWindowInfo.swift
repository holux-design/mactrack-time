import Foundation

struct FocusedWindowInfo: Equatable, Sendable {
    var appName: String
    var bundleIdentifier: String
    var windowTitle: String

    static let empty = FocusedWindowInfo(
        appName: "",
        bundleIdentifier: "",
        windowTitle: ""
    )
}
