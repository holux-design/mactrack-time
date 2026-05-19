import AppKit
import SwiftUI

private let timelineBlockGap: CGFloat = 2

struct DayTimelineBarView: View {
    let slices: [TimelineSlice]
    let projects: [Project]
    let day: Date
    var contentWidth: CGFloat?
    var zoom: CGFloat = TimelineViewport.defaultZoom
    var viewportWidth: CGFloat = 1
    var showsBackground: Bool = true
    var onAssignSelection: ((Date, Date, Project?) -> Void)?

    @Binding var selectionStart: Date?
    @Binding var selectionEnd: Date?
    @Binding var selectedSliceIDs: Set<UUID>

    init(
        slices: [TimelineSlice],
        projects: [Project],
        day: Date,
        contentWidth: CGFloat? = nil,
        zoom: CGFloat = TimelineViewport.defaultZoom,
        viewportWidth: CGFloat = 1,
        selectionStart: Binding<Date?>,
        selectionEnd: Binding<Date?>,
        selectedSliceIDs: Binding<Set<UUID>>,
        showsBackground: Bool = true,
        onAssignSelection: ((Date, Date, Project?) -> Void)? = nil
    ) {
        self.slices = slices
        self.projects = projects
        self.day = day
        self.contentWidth = contentWidth
        self.zoom = zoom
        self.viewportWidth = viewportWidth
        self.showsBackground = showsBackground
        self.onAssignSelection = onAssignSelection
        _selectionStart = selectionStart
        _selectionEnd = selectionEnd
        _selectedSliceIDs = selectedSliceIDs
    }

    private var dayBounds: (start: Date, end: Date) {
        DayTimeline.dayBounds(for: day)
    }

    var body: some View {
        GeometryReader { geo in
            let width = contentWidth ?? geo.size.width
            let barHeight = geo.size.height
            ZStack(alignment: .leading) {
                if showsBackground {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary.opacity(0.4))
                }

                ForEach(gridTicks(width: width), id: \.date.timeIntervalSince1970) { tick in
                    Rectangle()
                        .fill(Color.secondary.opacity(tick.kind.gridOpacity))
                        .frame(width: 1, height: barHeight)
                        .offset(x: xPosition(for: tick.date, width: width))
                }

                ForEach(slices) { slice in
                    let frame = frameFor(slice: slice, width: width)
                    sliceBlock(slice: slice, frame: frame, height: barHeight)
                }

                selectionOverlay(width: width, height: barHeight)
            }
            .frame(width: width, alignment: .leading)
            .overlay {
                TimelineBarMouseOverlay(
                    width: width,
                    height: barHeight,
                    showsBackground: showsBackground,
                    slices: slices,
                    projects: projects,
                    dayBounds: dayBounds,
                    selectionStart: $selectionStart,
                    selectionEnd: $selectionEnd,
                    selectedSliceIDs: $selectedSliceIDs,
                    onAssignSelection: onAssignSelection
                )
                .frame(width: width, height: barHeight)
            }
        }
    }

    private func gridTicks(width: CGFloat) -> [TimelineTick] {
        let effectiveViewportWidth = viewportWidth > 0 ? viewportWidth : width
        return DayTimeline.markerTicks(for: day, zoom: zoom, viewportWidth: effectiveViewportWidth)
    }

    private func xPosition(for date: Date, width: CGFloat) -> CGFloat {
        let (dayStart, dayEnd) = dayBounds
        let total = dayEnd.timeIntervalSince(dayStart)
        guard total > 0 else { return 0 }
        return CGFloat(date.timeIntervalSince(dayStart) / total) * width
    }

    @ViewBuilder
    private func sliceBlock(slice: TimelineSlice, frame: CGRect, height: CGFloat) -> some View {
        let visual = visualFrame(for: frame)
        let blockHeight = height - (showsBackground ? 8 : 4)
        let yInset: CGFloat = showsBackground ? 4 : 2
        RoundedRectangle(cornerRadius: 4)
            .fill(color(for: slice))
            .frame(width: visual.width, height: blockHeight)
            .offset(x: visual.minX, y: yInset)
            .help(helpText(for: slice))
            .allowsHitTesting(false)
    }

    private func visualFrame(for frame: CGRect) -> CGRect {
        CGRect(
            x: frame.minX + timelineBlockGap / 2,
            y: frame.minY,
            width: max(2, frame.width - timelineBlockGap),
            height: frame.height
        )
    }

    private func color(for slice: TimelineSlice) -> Color {
        if slice.segment.projectID == nil {
            return Color.secondary.opacity(0.35)
        }
        guard let id = slice.segment.projectID,
              let project = projects.first(where: { $0.id == id }) else {
            return .accentColor
        }
        return ProjectColors.color(from: project.colorHex)
    }

    private func frameFor(slice: TimelineSlice, width: CGFloat) -> CGRect {
        let (dayStart, dayEnd) = dayBounds
        let total = dayEnd.timeIntervalSince(dayStart)
        guard total > 0 else { return .zero }
        let x = CGFloat(slice.start.timeIntervalSince(dayStart) / total) * width
        let w = CGFloat(slice.end.timeIntervalSince(slice.start) / total) * width
        return CGRect(x: x, y: 0, width: w, height: 0)
    }

    @ViewBuilder
    private func selectionOverlay(width: CGFloat, height: CGFloat) -> some View {
        let inset: CGFloat = showsBackground ? 4 : 2
        let overlayHeight = height - inset * 2

        if !selectedSliceIDs.isEmpty {
            ForEach(slices.filter { selectedSliceIDs.contains($0.id) }) { slice in
                selectionHighlight(for: slice, width: width, height: overlayHeight, yInset: inset)
            }
        } else if let start = selectionStart, let end = selectionEnd, end > start {
            let (dayStart, dayEnd) = dayBounds
            let total = dayEnd.timeIntervalSince(dayStart)
            if total > 0 {
                let x = CGFloat(start.timeIntervalSince(dayStart) / total) * width
                let w = CGFloat(end.timeIntervalSince(start) / total) * width
                let rectWidth = max(4, w)
                selectionHighlightRect(x: x, width: rectWidth, height: overlayHeight, yInset: inset)
                selectionDurationLabel(
                    duration: end.timeIntervalSince(start),
                    centerX: x + rectWidth / 2,
                    barTopY: inset
                )
            }
        }
    }

    private func selectionDurationLabel(duration: TimeInterval, centerX: CGFloat, barTopY: CGFloat) -> some View {
        Text(DurationFormatting.short(duration))
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 5))
            .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
            .fixedSize()
            .position(x: centerX, y: barTopY - 17)
            .allowsHitTesting(false)
    }

    private func selectionHighlight(for slice: TimelineSlice, width: CGFloat, height: CGFloat, yInset: CGFloat) -> some View {
        let frame = frameFor(slice: slice, width: width)
        let visual = visualFrame(for: frame)
        return selectionHighlightRect(x: visual.minX, width: visual.width, height: height, yInset: yInset)
    }

    private func selectionHighlightRect(x: CGFloat, width: CGFloat, height: CGFloat, yInset: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .strokeBorder(Color.accentColor, lineWidth: 2)
            .background(Color.accentColor.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            .frame(width: width, height: height)
            .offset(x: x, y: yInset)
            .allowsHitTesting(false)
    }

    private func helpText(for slice: TimelineSlice) -> String {
        let title = slice.segment.windowTitle.isEmpty ? slice.segment.appName : slice.segment.windowTitle
        return "\(title) · \(DurationFormatting.short(slice.duration))"
    }
}

// MARK: - AppKit mouse handling

private struct TimelineBarMouseOverlay: NSViewRepresentable {
    let width: CGFloat
    let height: CGFloat
    let showsBackground: Bool
    let slices: [TimelineSlice]
    let projects: [Project]
    let dayBounds: (start: Date, end: Date)
    @Binding var selectionStart: Date?
    @Binding var selectionEnd: Date?
    @Binding var selectedSliceIDs: Set<UUID>
    let onAssignSelection: ((Date, Date, Project?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> TimelineBarMouseView {
        let view = TimelineBarMouseView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: TimelineBarMouseView, context: Context) {
        context.coordinator.parent = self
        nsView.coordinator = context.coordinator
        nsView.needsLayout = true
    }

    final class Coordinator: NSObject {
        var parent: TimelineBarMouseOverlay
        var selectionAnchorSliceID: UUID?

        init(parent: TimelineBarMouseOverlay) {
            self.parent = parent
        }

        func selectRange(from start: Date, to end: Date) {
            parent.selectedSliceIDs = []
            parent.selectionStart = start
            parent.selectionEnd = end
        }

        func clearSelection() {
            selectionAnchorSliceID = nil
            parent.selectedSliceIDs = []
            parent.selectionStart = nil
            parent.selectionEnd = nil
        }

        func selectSingleSlice(_ slice: TimelineSlice) {
            selectionAnchorSliceID = slice.id
            parent.selectedSliceIDs = []
            parent.selectionStart = slice.start
            parent.selectionEnd = slice.end
        }

        func selectSliceRange(from anchor: TimelineSlice, to target: TimelineSlice) {
            let (start, end) = parent.blockRange(from: anchor, to: target)
            parent.selectedSliceIDs = []
            parent.selectionStart = start
            parent.selectionEnd = end
        }

        func toggleSliceSelection(_ slice: TimelineSlice) {
            var ids = parent.selectedSliceIDs
            if ids.isEmpty,
               let start = parent.selectionStart,
               let end = parent.selectionEnd,
               end > start {
                ids = Set(parent.slices.filter { $0.end > start && $0.start < end }.map(\.id))
            }

            if ids.contains(slice.id) {
                ids.remove(slice.id)
            } else {
                ids.insert(slice.id)
                if selectionAnchorSliceID == nil {
                    selectionAnchorSliceID = slice.id
                }
            }

            parent.selectedSliceIDs = ids
            syncRangeFromSelectedSlices()
        }

        private func syncRangeFromSelectedSlices() {
            let selected = parent.slices.filter { parent.selectedSliceIDs.contains($0.id) }
            guard !selected.isEmpty else {
                clearSelection()
                return
            }
            parent.selectionStart = selected.map(\.start).min()
            parent.selectionEnd = selected.map(\.end).max()
        }
    }
}

private final class TimelineBarMouseView: NSView {
    weak var coordinator: TimelineBarMouseOverlay.Coordinator?

    private var dragAnchorX: CGFloat?
    private var didDrag = false
    private let dragThreshold: CGFloat = 4

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    // MARK: Left click / drag

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            handleContextClick(event)
            return
        }
        guard event.buttonNumber == 0 else {
            super.mouseDown(with: event)
            return
        }
        if event.modifierFlags.intersection([.shift, .command]).isEmpty {
            dragAnchorX = localX(for: event)
        } else {
            dragAnchorX = nil
        }
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 0,
              let anchor = dragAnchorX,
              let coordinator else {
            super.mouseDragged(with: event)
            return
        }

        let current = localX(for: event)
        if !didDrag, abs(current - anchor) < dragThreshold { return }

        didDrag = true
        coordinator.selectionAnchorSliceID = nil
        let range = coordinator.parent.selectionDates(fromX: anchor, toX: current)
        coordinator.selectRange(from: range.start, to: range.end)
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragAnchorX = nil
            didDrag = false
        }

        guard event.buttonNumber == 0,
              !event.modifierFlags.contains(.control),
              let coordinator else {
            super.mouseUp(with: event)
            return
        }

        guard !didDrag else { return }

        let x = localX(for: event)
        if let slice = coordinator.parent.slice(at: x) {
            if event.modifierFlags.contains(.command) {
                coordinator.toggleSliceSelection(slice)
            } else if event.modifierFlags.contains(.shift),
                      let anchorID = coordinator.selectionAnchorSliceID,
                      let anchor = coordinator.parent.slices.first(where: { $0.id == anchorID }) {
                coordinator.selectSliceRange(from: anchor, to: slice)
            } else {
                coordinator.selectSingleSlice(slice)
            }
            return
        }
        if !coordinator.parent.selectedSliceIDs.isEmpty {
            coordinator.clearSelection()
            return
        }
        if coordinator.parent.selectionContains(x: x) { return }
        coordinator.clearSelection()
    }

    // MARK: Right click

    override func rightMouseDown(with event: NSEvent) {
        handleContextClick(event)
    }

    private func handleContextClick(_ event: NSEvent) {
        guard let coordinator else { return }
        let x = localX(for: event)

        if let slice = coordinator.parent.slice(at: x),
           coordinator.parent.isSliceInSelection(slice),
           let bounds = coordinator.parent.selectionMenuBounds() {
            showProjectMenu(for: bounds.start, end: bounds.end, event: event)
            return
        }

        if let (start, end) = coordinator.parent.selectionRange,
           coordinator.parent.selectedSliceIDs.isEmpty,
           coordinator.parent.selectionContains(x: x, start: start, end: end) {
            showProjectMenu(for: start, end: end, event: event)
            return
        }

        if let slice = coordinator.parent.slice(at: x) {
            coordinator.selectSingleSlice(slice)
            showProjectMenu(for: slice.start, end: slice.end, event: event)
            return
        }
    }

    private func showProjectMenu(for start: Date, end: Date, event: NSEvent) {
        guard let coordinator, let onAssign = coordinator.parent.onAssignSelection else { return }

        let menu = NSMenu()

        let untrackedItem = NSMenuItem(title: "Untracked", action: #selector(assignProject(_:)), keyEquivalent: "")
        untrackedItem.target = self
        untrackedItem.representedObject = AssignmentPayload(
            start: start,
            end: end,
            project: nil,
            handler: onAssign,
            clearSelection: { coordinator.clearSelection() }
        )
        untrackedItem.image = coloredDotImage(color: .secondaryLabelColor)
        menu.addItem(untrackedItem)

        if !coordinator.parent.projects.isEmpty {
            menu.addItem(.separator())
            for project in coordinator.parent.projects {
                let item = NSMenuItem(title: project.name, action: #selector(assignProject(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = AssignmentPayload(
                    start: start,
                    end: end,
                    project: project,
                    handler: onAssign,
                    clearSelection: { coordinator.clearSelection() }
                )
                item.image = coloredDotImage(hex: project.colorHex)
                menu.addItem(item)
            }
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func assignProject(_ sender: NSMenuItem) {
        guard let payload = sender.representedObject as? AssignmentPayload else { return }
        payload.handler(payload.start, payload.end, payload.project)
        payload.clearSelection()
    }

    private func localX(for event: NSEvent) -> CGFloat {
        convert(event.locationInWindow, from: nil).x
    }

    private func coloredDotImage(hex: String) -> NSImage? {
        coloredDotImage(color: ProjectColors.nsColor(from: hex))
    }

    private func coloredDotImage(color: NSColor) -> NSImage? {
        let size: CGFloat = 10
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        return image
    }
}

private final class AssignmentPayload: NSObject {
    let start: Date
    let end: Date
    let project: Project?
    let handler: (Date, Date, Project?) -> Void
    let clearSelection: () -> Void

    init(
        start: Date,
        end: Date,
        project: Project?,
        handler: @escaping (Date, Date, Project?) -> Void,
        clearSelection: @escaping () -> Void
    ) {
        self.start = start
        self.end = end
        self.project = project
        self.handler = handler
        self.clearSelection = clearSelection
    }
}

private extension TimelineBarMouseOverlay {
    var selectionRange: (Date, Date)? {
        guard let start = selectionStart, let end = selectionEnd, end > start else { return nil }
        return (start, end)
    }

    func date(at x: CGFloat) -> Date {
        let (dayStart, dayEnd) = dayBounds
        let total = dayEnd.timeIntervalSince(dayStart)
        let fraction = max(0, min(1, Double(x / width)))
        return dayStart.addingTimeInterval(total * fraction)
    }

    func selectionDates(fromX x1: CGFloat, toX x2: CGFloat) -> (start: Date, end: Date) {
        let rawStart = date(at: x1)
        let rawEnd = date(at: x2)
        return DayTimeline.snappedSelection(
            start: rawStart,
            end: rawEnd,
            on: dayBounds.start,
            interval: AppSettings.shared.timelineSnap
        )
    }

    func slice(at x: CGFloat) -> TimelineSlice? {
        slices.first { slice in
            let frame = visualFrameFor(slice: slice)
            return x >= frame.minX && x <= frame.maxX
        }
    }

    func frameFor(slice: TimelineSlice) -> CGRect {
        let (dayStart, dayEnd) = dayBounds
        let total = dayEnd.timeIntervalSince(dayStart)
        guard total > 0 else { return .zero }
        let sliceX = CGFloat(slice.start.timeIntervalSince(dayStart) / total) * width
        let sliceW = CGFloat(slice.end.timeIntervalSince(slice.start) / total) * width
        return CGRect(x: sliceX, y: 0, width: sliceW, height: 0)
    }

    func visualFrameFor(slice: TimelineSlice) -> CGRect {
        let full = frameFor(slice: slice)
        return CGRect(
            x: full.minX + timelineBlockGap / 2,
            y: full.minY,
            width: max(2, full.width - timelineBlockGap),
            height: full.height
        )
    }

    func blockRange(from anchor: TimelineSlice, to target: TimelineSlice) -> (start: Date, end: Date) {
        let sorted = slices.sorted { $0.start < $1.start }
        guard let anchorIndex = sorted.firstIndex(where: { $0.id == anchor.id }),
              let targetIndex = sorted.firstIndex(where: { $0.id == target.id }) else {
            return (target.start, target.end)
        }
        let low = min(anchorIndex, targetIndex)
        let high = max(anchorIndex, targetIndex)
        let range = sorted[low...high]
        return (range.first!.start, range.last!.end)
    }

    func isSliceInSelection(_ slice: TimelineSlice) -> Bool {
        if !selectedSliceIDs.isEmpty {
            return selectedSliceIDs.contains(slice.id)
        }
        guard let start = selectionStart, let end = selectionEnd, end > start else { return false }
        return slice.end > start && slice.start < end
    }

    func selectionMenuBounds() -> (start: Date, end: Date)? {
        if !selectedSliceIDs.isEmpty {
            let selected = slices.filter { selectedSliceIDs.contains($0.id) }
            guard let start = selected.map(\.start).min(),
                  let end = selected.map(\.end).max(),
                  end > start else { return nil }
            return (start, end)
        }
        return selectionRange
    }

    func selectionContains(x: CGFloat, start: Date? = nil, end: Date? = nil) -> Bool {
        let rangeStart = start ?? selectionStart
        let rangeEnd = end ?? selectionEnd
        guard let rangeStart, let rangeEnd, rangeEnd > rangeStart else { return false }
        let (dayStart, dayEnd) = dayBounds
        let total = dayEnd.timeIntervalSince(dayStart)
        guard total > 0 else { return false }
        let selX = CGFloat(rangeStart.timeIntervalSince(dayStart) / total) * width
        let selW = CGFloat(rangeEnd.timeIntervalSince(rangeStart) / total) * width
        return x >= selX && x <= selX + selW
    }
}

private extension ProjectColors {
    static func nsColor(from hex: String) -> NSColor {
        NSColor(Self.color(from: hex))
    }
}
