import AppKit
import Combine
import Foundation

@MainActor
final class WindowFocusTracker: ObservableObject {
    @Published private(set) var currentWindow: FocusedWindowInfo = .empty
    @Published private(set) var accessibilityGranted = AccessibilityWindowReader.isTrusted
    @Published private(set) var screenCaptureGranted = AccessibilityWindowReader.hasScreenCaptureAccess

    private var pollTimer: Timer?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var appObservers: [NSObjectProtocol] = []
    private var isPolling = false

    var onFocusChange: ((FocusedWindowInfo) -> Void)?

    func start(pollInterval: TimeInterval = 1.0) {
        stop()
        refreshAccessibilityStatus()
        registerAppObservers()

        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollFocusedWindow()
            }
        }
        if let timer = pollTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.pollFocusedWindow()
                }
            }
        ]
        pollFocusedWindow()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        workspaceObservers = []
        appObservers.forEach { NotificationCenter.default.removeObserver($0) }
        appObservers = []
    }

    func refreshAccessibilityStatus() {
        accessibilityGranted = AccessibilityWindowReader.isTrusted
        screenCaptureGranted = AccessibilityWindowReader.hasScreenCaptureAccess
    }

    func openScreenCaptureSettings() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if !AccessibilityWindowReader.hasScreenCaptureAccess {
                _ = AccessibilityWindowReader.requestScreenCaptureAccess()
            }
            AccessibilityWindowReader.openScreenCaptureSettings()
            self.refreshAccessibilityStatus()
        }
    }

    func requestAccessibility() {
        AccessibilityWindowReader.requestTrust()
        refreshAccessibilityStatus()
    }

    func openAccessibilitySettings() {
        AccessibilityWindowReader.requestTrust()
        refreshAccessibilityStatus()
    }

    private func registerAppObservers() {
        let center = NotificationCenter.default
        appObservers = [
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleReturnToApp()
            }
        ]
    }

    private func handleReturnToApp() {
        DockVisibility.restoreAccessoryIfNeeded()
        refreshAccessibilityStatus()
        pollFocusedWindow()
    }

    private func pollFocusedWindow() {
        guard !isPolling else { return }
        isPolling = true
        defer { isPolling = false }

        refreshAccessibilityStatus()
        guard let app = NSWorkspace.shared.frontmostApplication else {
            applyFocus(.empty)
            return
        }
        let info = AccessibilityWindowReader.focusedWindow(for: app)
        applyFocus(info)
    }

    private func applyFocus(_ info: FocusedWindowInfo) {
        currentWindow = info
        onFocusChange?(info)
    }
}
