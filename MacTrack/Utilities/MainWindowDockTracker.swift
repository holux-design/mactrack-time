import AppKit
import SwiftUI

struct MainWindowDockTracker: NSViewRepresentable {
    func makeNSView(context: Context) -> MainWindowDockTrackingView {
        MainWindowDockTrackingView()
    }

    func updateNSView(_ nsView: MainWindowDockTrackingView, context: Context) {}
}

final class MainWindowDockTrackingView: NSView {
    private weak var trackedWindow: NSWindow?
    private var closeObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard let window else {
            stopTracking()
            return
        }
        guard window !== trackedWindow else { return }

        stopTracking()
        trackedWindow = window
        DockVisibility.mainWindowDidOpen()

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.stopTracking()
        }
    }

    deinit {
        stopTracking()
    }

    private func stopTracking() {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
            self.closeObserver = nil
        }
        guard trackedWindow != nil else { return }
        trackedWindow = nil
        DockVisibility.mainWindowDidClose()
    }
}
