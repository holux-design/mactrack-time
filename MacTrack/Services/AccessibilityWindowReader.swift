import AppKit
import ApplicationServices
import CoreGraphics

enum AccessibilityWindowReader {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static var hasScreenCaptureAccess: Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightScreenCaptureAccess()
        }
        return true
    }

    @discardableResult
    static func registerForAccessibility(prompt: Bool = true) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func requestTrust() {
        _ = registerForAccessibility(prompt: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            openAccessibilitySettings()
        }
    }

    @discardableResult
    static func requestScreenCaptureAccess() -> Bool {
        if #available(macOS 10.15, *) {
            return CGRequestScreenCaptureAccess()
        }
        return true
    }

    @discardableResult
    static func openAccessibilitySettings() -> Bool {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }

    @discardableResult
    static func openScreenCaptureSettings() -> Bool {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_ScreenCapture",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture",
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return true
            }
        }
        return false
    }

    // MARK: - Known browsers

    static let browserBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.google.Chrome",
        "com.google.Chrome.canary",
        "company.thebrowser.Browser",   // Arc
        "org.mozilla.firefox",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "org.chromium.Chromium",
    ]

    static func isBrowser(bundleID: String) -> Bool {
        browserBundleIDs.contains(bundleID)
    }

    // MARK: - Known Electron / web-based apps (AXWebArea BFS is only worth attempting for these)

    static let electronBundleIDs: Set<String> = [
        "com.anthropic.claude",         // Claude
        "com.notion.id",                // Notion
        "com.tinyspeck.slackmacgap",    // Slack
        "com.discord.Discord",          // Discord
        "com.microsoft.teams",          // Teams (v1)
        "com.microsoft.teams2",         // Teams (v2)
        "com.github.GitHubDesktop",     // GitHub Desktop
        "md.obsidian",                  // Obsidian
        "com.figma.Desktop",            // Figma
        "com.linear.linear",            // Linear
        "com.spotify.client",           // Spotify
        "com.microsoft.VSCode",         // VS Code
        "com.todesktop.230313mzl4w4u92",// Cursor
        "com.loom.desktop",             // Loom
        "com.zulip.zulip",              // Zulip
        "com.mattermost.desktop",       // Mattermost
        "com.bitwarden.desktop",        // Bitwarden
    ]

    static func isElectronApp(bundleID: String) -> Bool {
        electronBundleIDs.contains(bundleID)
    }

    static func focusedWindow(for app: NSRunningApplication) -> FocusedWindowInfo {
        let appName = app.localizedName ?? ""
        let bundleID = app.bundleIdentifier ?? ""
        let pid = app.processIdentifier

        var title = ""
        if isTrusted {
            title = titleViaAccessibility(pid: pid)
        }
        if title.isEmpty, hasScreenCaptureAccess {
            title = titleViaWindowList(pid: pid)
        }

        var url = ""
        if isTrusted, isBrowser(bundleID: bundleID) {
            url = extractBrowserURL(pid: pid)
        }

        // For known Electron/web apps with empty titles, try reading the AXWebArea title.
        // Deliberately limited to the known-Electron allowlist — running a BFS over the
        // full accessibility tree of arbitrary apps every second is too expensive.
        if title.isEmpty, isTrusted, isElectronApp(bundleID: bundleID) {
            title = webAreaTitle(pid: pid)
        }


        return FocusedWindowInfo(
            appName: appName,
            bundleIdentifier: bundleID,
            windowTitle: title,
            url: url
        )
    }

    // MARK: - Browser URL extraction

    private static func extractBrowserURL(pid: pid_t) -> String {
        let appElement = AXUIElementCreateApplication(pid)
        let window = copyAXElement(appElement, kAXFocusedWindowAttribute as String)
            ?? copyAXElement(appElement, kAXMainWindowAttribute as String)

        // kAXDocumentAttribute on the window returns the current page URL in most browsers
        if let w = window,
           let doc = copyString(w, kAXDocumentAttribute as String),
           looksLikeURL(doc) {
            return doc
        }

        // Fallback: scan toolbar text fields for something that looks like a URL
        if let w = window, let url = urlFromAddressBar(w) {
            return url
        }

        return ""
    }

    private static func urlFromAddressBar(_ window: AXUIElement) -> String? {
        for toolbar in childElements(of: window, withRole: "AXToolbar") {
            for field in childElements(of: toolbar, withRole: kAXTextFieldRole as String) {
                if let value = copyString(field, kAXValueAttribute as String),
                   looksLikeURL(value) {
                    return value
                }
            }
        }
        return nil
    }

    private static func childElements(of element: AXUIElement, withRole role: String) -> [AXUIElement] {
        (copyAXElementArray(element, kAXChildrenAttribute as String) ?? []).filter {
            copyString($0, kAXRoleAttribute as String) == role
        }
    }

    static func looksLikeURL(_ string: String) -> Bool {
        string.hasPrefix("https://") || string.hasPrefix("http://")
    }

    // MARK: - Title resolution chain

    private static func titleViaAccessibility(pid: pid_t) -> String {
        if let title = titleViaSystemWideFocusedWindow(expectedPID: pid), !title.isEmpty {
            return title
        }
        if let title = titleViaApplicationElement(pid: pid), !title.isEmpty {
            return title
        }
        return ""
    }

    private static func titleViaSystemWideFocusedWindow(expectedPID: pid_t) -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        guard let window = copyAXElement(systemWide, kAXFocusedWindowAttribute as String) else {
            return nil
        }
        var windowPID: pid_t = 0
        guard AXUIElementGetPid(window, &windowPID) == .success, windowPID == expectedPID else {
            return nil
        }
        return bestTitle(for: window)
    }

    private static func titleViaApplicationElement(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)

        if let focused = copyAXElement(appElement, kAXFocusedWindowAttribute as String),
           let title = bestTitle(for: focused), !title.isEmpty {
            return title
        }

        if let main = copyAXElement(appElement, kAXMainWindowAttribute as String),
           let title = bestTitle(for: main), !title.isEmpty {
            return title
        }

        let windows = copyAXElementArray(appElement, kAXWindowsAttribute as String) ?? []
        let ranked = windows
            .compactMap { window -> (AXUIElement, Int)? in
                let score = windowScore(window)
                return score > 0 ? (window, score) : nil
            }
            .sorted { $0.1 > $1.1 }

        for (window, _) in ranked {
            if let title = bestTitle(for: window), !title.isEmpty {
                return title
            }
        }

        return nil
    }

    private static func bestTitle(for window: AXUIElement) -> String? {
        if let direct = titleFromElement(window) {
            return direct
        }
        if let focusedChild = copyAXElement(window, kAXFocusedUIElementAttribute as String),
           let childTitle = titleFromElement(focusedChild) {
            return childTitle
        }
        return titleFromElementTree(window, maxDepth: 5)
    }

    private static func titleFromElement(_ element: AXUIElement) -> String? {
        // Direct title first
        if let title = copyString(element, kAXTitleAttribute as String), !title.isEmpty {
            return title
        }

        // AXDocument: native apps expose an open file as a file:// URL → extract filename.
        // Skip raw http(s) URLs here — those are handled separately as browser URLs.
        if let doc = copyString(element, kAXDocumentAttribute as String), !doc.isEmpty {
            if doc.hasPrefix("file://"), let fileURL = URL(string: doc) {
                let name = fileURL.lastPathComponent
                return name.isEmpty ? nil : name
            }
            if !looksLikeURL(doc) {
                return doc
            }
        }

        // Fall through to description / value
        for attribute in [kAXDescriptionAttribute as String, kAXValueAttribute as String] {
            if let value = copyString(element, attribute), !value.isEmpty {
                return value
            }
        }
        return nil
    }

    private static func titleFromElementTree(_ element: AXUIElement, maxDepth: Int, depth: Int = 0) -> String? {
        guard depth <= maxDepth else { return nil }
        if let title = titleFromElement(element), !title.isEmpty {
            return title
        }
        guard let children = copyAXElementArray(element, kAXChildrenAttribute as String) else {
            return nil
        }
        for child in children {
            if let title = titleFromElementTree(child, maxDepth: maxDepth, depth: depth + 1), !title.isEmpty {
                return title
            }
        }
        return nil
    }

    private static func windowScore(_ window: AXUIElement) -> Int {
        var score = 0
        if copyBool(window, kAXMainAttribute as String) == true { score += 100 }
        if copyBool(window, kAXFocusedAttribute as String) == true { score += 80 }
        if copyBool(window, kAXMinimizedAttribute as String) == true { score -= 200 }
        if let size = copySize(window) {
            score += Int(min(size.width * size.height / 10_000, 50))
        }
        if titleFromElement(window) != nil { score += 20 }
        return score
    }

    // MARK: - CGWindowList (needs Screen Recording on recent macOS)

    private static func titleViaWindowList(pid: pid_t) -> String {
        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return ""
        }

        let candidates: [(name: String, score: CGFloat)] = windowList.compactMap { info in
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                return nil
            }
            let name = (info[kCGWindowName as String] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty else { return nil }

            let bounds = info[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
            let width = bounds["Width"] ?? 0
            let height = bounds["Height"] ?? 0
            var score = width * height
            if let alpha = info[kCGWindowAlpha as String] as? CGFloat, alpha < 0.1 {
                score = 0
            }
            return (name, score)
        }

        return candidates.max(by: { $0.score < $1.score })?.name ?? ""
    }

    // MARK: - Web area / Electron title extraction

    /// For Electron and other web-based apps, the accessibility tree contains an AXWebArea
    /// whose title maps to the HTML <title> tag, and AXHeading elements for visible headings.
    private static func webAreaTitle(pid: pid_t) -> String {
        let appEl = AXUIElementCreateApplication(pid)
        let window = copyAXElement(appEl, kAXFocusedWindowAttribute as String)
            ?? copyAXElement(appEl, kAXMainWindowAttribute as String)
        guard let window else { return "" }

        guard let webArea = findElement(withRole: "AXWebArea", in: window, maxDepth: 5) else {
            return ""
        }

        // 1. AXTitle on the web area = HTML <title> tag (e.g. "My Conversation — Claude")
        if let t = copyString(webArea, kAXTitleAttribute as String), !t.isEmpty {
            return cleanWebTitle(t)
        }

        // 2. First AXHeading in the web content (e.g. conversation heading)
        if let heading = findElement(withRole: "AXHeading", in: webArea, maxDepth: 8),
           let t = firstMeaningfulText(heading), !t.isEmpty {
            return t
        }

        return ""
    }

    /// Strip common app-name suffixes like " — Claude" or " | Notion" from page titles.
    private static func cleanWebTitle(_ raw: String) -> String {
        let separators = [" — ", " - ", " | ", " · "]
        for sep in separators {
            if let range = raw.range(of: sep) {
                let prefix = String(raw[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
                if !prefix.isEmpty { return prefix }
            }
        }
        return raw
    }

    private static func firstMeaningfulText(_ element: AXUIElement) -> String? {
        for attr in [kAXValueAttribute as String, kAXTitleAttribute as String, kAXDescriptionAttribute as String] {
            if let v = copyString(element, attr), v.count > 2 { return v }
        }
        return nil
    }

    /// BFS search for the first element matching a given role within maxDepth levels.
    /// Uses an index cursor instead of removeFirst() to avoid O(n) array copies on each dequeue.
    private static func findElement(withRole role: String, in root: AXUIElement, maxDepth: Int) -> AXUIElement? {
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var index = 0
        while index < queue.count {
            let (el, depth) = queue[index]
            index += 1
            if copyString(el, kAXRoleAttribute as String) == role { return el }
            guard depth < maxDepth else { continue }
            for child in copyAXElementArray(el, kAXChildrenAttribute as String) ?? [] {
                queue.append((child, depth + 1))
            }
        }
        return nil
    }

    // MARK: - AX helpers

    private static func copyAXElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let ref = value else {
            return nil
        }
        return ref as! AXUIElement
    }

    private static func copyAXElementArray(_ element: AXUIElement, _ attribute: String) -> [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let ref = value else {
            return nil
        }

        if let array = ref as? [AXUIElement] {
            return array
        }

        guard CFGetTypeID(ref) == CFArrayGetTypeID() else { return nil }
        let cfArray = ref as! CFArray
        let count = CFArrayGetCount(cfArray)
        var elements: [AXUIElement] = []
        elements.reserveCapacity(count)
        for index in 0..<count {
            let raw = CFArrayGetValueAtIndex(cfArray, index)
            elements.append(unsafeBitCast(raw, to: AXUIElement.self))
        }
        return elements
    }

    private static func copyString(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let ref = value else {
            return nil
        }
        if let string = ref as? String { return string }
        if let string = ref as? NSString { return string as String }
        if CFGetTypeID(ref) == CFStringGetTypeID() {
            return (ref as! CFString) as String
        }
        if CFGetTypeID(ref) == CFAttributedStringGetTypeID() {
            return (ref as! NSAttributedString).string
        }
        return nil
    }

    private static func copyBool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let ref = value else {
            return nil
        }
        if let bool = ref as? Bool { return bool }
        if let number = ref as? NSNumber { return number.boolValue }
        return nil
    }

    private static func copySize(_ element: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &value) == .success,
              let ref = value else {
            return nil
        }
        var size = CGSize.zero
        if CFGetTypeID(ref) == AXValueGetTypeID() {
            AXValueGetValue(ref as! AXValue, .cgSize, &size)
            return size
        }
        return nil
    }
}
