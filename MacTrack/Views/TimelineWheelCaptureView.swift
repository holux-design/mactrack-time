import AppKit
import SwiftUI

struct TimelineScrollWheelModifier: ViewModifier {
    @Binding var viewport: TimelineViewport
    @State private var windowFrame: CGRect = .zero
    @State private var monitor = TimelineScrollWheelMonitor()

    func body(content: Content) -> some View {
        content
            .background(TimelineWindowFrameReader { frame in
                windowFrame = frame
                monitor.windowFrame = frame
            })
            .onAppear {
                monitor.onZoom = { factor, viewportX in
                    let width = max(windowFrame.width, 1)
                    viewport.zoom(by: factor, at: viewportX, viewportWidth: width)
                }
                monitor.onPan = { deltaX in
                    let width = max(windowFrame.width, 1)
                    viewport.pan(by: deltaX, viewportWidth: width)
                }
                monitor.install()
            }
            .onDisappear {
                monitor.teardown()
            }
    }
}

extension View {
    func timelineScrollWheel(viewport: Binding<TimelineViewport>) -> some View {
        modifier(TimelineScrollWheelModifier(viewport: viewport))
    }
}

private struct TimelineWindowFrameReader: NSViewRepresentable {
    var onUpdate: (CGRect) -> Void

    func makeNSView(context: Context) -> TimelineWindowFrameNSView {
        let view = TimelineWindowFrameNSView()
        view.onUpdate = onUpdate
        return view
    }

    func updateNSView(_ nsView: TimelineWindowFrameNSView, context: Context) {
        nsView.onUpdate = onUpdate
        nsView.reportFrame()
    }
}

private final class TimelineWindowFrameNSView: NSView {
    var onUpdate: ((CGRect) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        reportFrame()
    }

    override func layout() {
        super.layout()
        reportFrame()
    }

    func reportFrame() {
        guard let window else { return }
        let rectInWindow = convert(bounds, to: nil)
        let rectOnScreen = window.convertToScreen(rectInWindow)
        onUpdate?(rectOnScreen)
    }
}

final class TimelineScrollWheelMonitor {
    var windowFrame: CGRect = .zero
    var onZoom: ((_ factor: CGFloat, _ viewportX: CGFloat) -> Void)?
    var onPan: ((_ deltaX: CGFloat) -> Void)?

    private var eventMonitor: Any?

    func install() {
        guard eventMonitor == nil else { return }
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.windowFrame.width > 0 else { return event }
            let mouse = NSEvent.mouseLocation
            guard self.windowFrame.contains(mouse) else { return event }
            self.handle(event, mouse: mouse)
            return nil
        }
    }

    func teardown() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handle(_ event: NSEvent, mouse: NSPoint) {
        let viewportX = mouse.x - windowFrame.minX

        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            applyPan(event)
            return
        }

        let delta = scrollDeltaY(event)
        guard delta != 0 else {
            applyPan(event)
            return
        }

        let factor = CGFloat(exp(-Double(delta) * 0.002))
        onZoom?(factor, viewportX)
    }

    private func applyPan(_ event: NSEvent) {
        var deltaX = scrollDeltaX(event)
        if deltaX == 0, event.modifierFlags.contains(.shift) {
            deltaX = scrollDeltaY(event)
        }
        guard deltaX != 0 else { return }
        onPan?(deltaX)
    }

    private func scrollDeltaY(_ event: NSEvent) -> CGFloat {
        event.scrollingDeltaY != 0 ? event.scrollingDeltaY : event.deltaY
    }

    private func scrollDeltaX(_ event: NSEvent) -> CGFloat {
        event.scrollingDeltaX != 0 ? event.scrollingDeltaX : event.deltaX
    }
}
