import Foundation

struct FocusedWindowInfo: Equatable, Sendable {
    var appName: String
    var bundleIdentifier: String
    var windowTitle: String
    var url: String

    init(appName: String, bundleIdentifier: String, windowTitle: String, url: String = "") {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.url = url
    }

    static let empty = FocusedWindowInfo(
        appName: "",
        bundleIdentifier: "",
        windowTitle: ""
    )
}
