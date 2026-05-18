import SwiftUI

struct DayTimelineView: View {
    let slices: [TimelineSlice]
    let projects: [Project]
    let day: Date
    var onAssignSelection: ((Date, Date, Project?) -> Void)?

    @Binding var selectionStart: Date?
    @Binding var selectionEnd: Date?
    @Binding var selectedSliceIDs: Set<UUID>

    @State private var viewport = TimelineViewport()
    @State private var optionPanStartOffset: CGFloat?
    @State private var didApplyDefaultViewport = false

    init(
        slices: [TimelineSlice],
        projects: [Project],
        day: Date,
        selectionStart: Binding<Date?>,
        selectionEnd: Binding<Date?>,
        selectedSliceIDs: Binding<Set<UUID>>,
        onAssignSelection: ((Date, Date, Project?) -> Void)? = nil
    ) {
        self.slices = slices
        self.projects = projects
        self.day = day
        self.onAssignSelection = onAssignSelection
        _selectionStart = selectionStart
        _selectionEnd = selectionEnd
        _selectedSliceIDs = selectedSliceIDs
    }

    private var dayStart: Date {
        Calendar.current.startOfDay(for: day)
    }

    private var dayBounds: (start: Date, end: Date) {
        DayTimeline.dayBounds(for: day)
    }

    private func timelineTicks(viewportWidth: CGFloat) -> [TimelineTick] {
        DayTimeline.markerTicks(for: day, zoom: viewport.clampedZoom, viewportWidth: viewportWidth)
    }

    var body: some View {
        timelineViewport
    }

    private var timelineViewport: some View {
        GeometryReader { geo in
            let viewportWidth = geo.size.width
            let contentWidth = viewport.contentWidth(for: viewportWidth)

            ZStack(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 6) {
                    timeMarkersRow(contentWidth: contentWidth, viewportWidth: viewportWidth)
                        .frame(height: 28)
                    appIconsRow(contentWidth: contentWidth)
                        .frame(height: 28)
                    DayTimelineBarView(
                        slices: slices,
                        projects: projects,
                        day: day,
                        contentWidth: contentWidth,
                        zoom: viewport.clampedZoom,
                        viewportWidth: viewportWidth,
                        selectionStart: $selectionStart,
                        selectionEnd: $selectionEnd,
                        selectedSliceIDs: $selectedSliceIDs,
                        showsBackground: false,
                        onAssignSelection: onAssignSelection
                    )
                    .frame(height: 40)
                }
                .frame(width: contentWidth, alignment: .leading)
                .offset(x: -viewport.scrollOffset)
            }
            .frame(width: viewportWidth, alignment: .leading)
            .clipped()
            .timelineScrollWheel(viewport: $viewport)
            .simultaneousGesture(optionPanGesture(viewportWidth: viewportWidth))
            .onChange(of: geo.size.width) { _, newWidth in
                applyInitialViewportIfNeeded(viewportWidth: newWidth)
            }
            .onChange(of: dayStart) { previousDay, newDay in
                guard didApplyDefaultViewport, previousDay != newDay else { return }
                viewport.applyWorkDayDefault(viewportWidth: viewportWidth)
            }
        }
        .frame(height: 108)
    }

    private func applyInitialViewportIfNeeded(viewportWidth: CGFloat) {
        guard viewportWidth > 0 else { return }
        if !didApplyDefaultViewport {
            viewport.applyWorkDayDefault(viewportWidth: viewportWidth)
            didApplyDefaultViewport = true
        } else {
            viewport.clampScrollOffset(viewportWidth: viewportWidth)
        }
    }

    private func optionPanGesture(viewportWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .modifiers(.option)
            .onChanged { value in
                if optionPanStartOffset == nil {
                    optionPanStartOffset = viewport.scrollOffset
                }
                guard let start = optionPanStartOffset else { return }
                viewport.scrollOffset = start - value.translation.width
                viewport.clampScrollOffset(viewportWidth: viewportWidth)
            }
            .onEnded { _ in
                optionPanStartOffset = nil
            }
    }

    private func timeMarkersRow(contentWidth: CGFloat, viewportWidth: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(timelineTicks(viewportWidth: viewportWidth)) { tick in
                let x = xPosition(for: tick.date, contentWidth: contentWidth)
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.secondary.opacity(tick.kind.markerOpacity))
                        .frame(width: 1, height: tick.kind.markerHeight)
                    if tick.kind == .hour {
                        Text(tick.date, format: .dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
                .offset(x: max(0, x - (tick.kind == .hour ? 14 : 0.5)))
            }
        }
    }

    private let appBlockGap: CGFloat = 2

    private func appIconsRow(contentWidth: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary.opacity(0.25))

            ForEach(slices) { slice in
                let frame = frameFor(slice: slice, contentWidth: contentWidth)
                let blockWidth = max(18, frame.width - appBlockGap)
                let blockColor = AppIconColorProvider.color(forBundleIdentifier: slice.segment.bundleIdentifier)
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(blockColor)
                    AppIconView(bundleIdentifier: slice.segment.bundleIdentifier, size: 16)
                }
                .frame(width: blockWidth, height: 24)
                .offset(x: frame.minX + appBlockGap / 2, y: 2)
                .help(helpText(for: slice))
            }
        }
        .frame(height: 28)
    }

    private func xPosition(for date: Date, contentWidth: CGFloat) -> CGFloat {
        let (dayStart, dayEnd) = dayBounds
        let total = dayEnd.timeIntervalSince(dayStart)
        guard total > 0 else { return 0 }
        return CGFloat(date.timeIntervalSince(dayStart) / total) * contentWidth
    }

    private func frameFor(slice: TimelineSlice, contentWidth: CGFloat) -> CGRect {
        let (dayStart, dayEnd) = dayBounds
        let total = dayEnd.timeIntervalSince(dayStart)
        guard total > 0 else { return .zero }
        let x = CGFloat(slice.start.timeIntervalSince(dayStart) / total) * contentWidth
        let w = CGFloat(slice.end.timeIntervalSince(slice.start) / total) * contentWidth
        return CGRect(x: x, y: 0, width: w, height: 0)
    }

    private func helpText(for slice: TimelineSlice) -> String {
        let title = slice.segment.windowTitle.isEmpty ? slice.segment.appName : slice.segment.windowTitle
        return "\(title) · \(DurationFormatting.short(slice.duration))"
    }
}

struct DayTimelineSection: View {
    let slices: [TimelineSlice]
    let projects: [Project]
    let day: Date
    var height: CGFloat = 108

    @Binding var selectionStart: Date?
    @Binding var selectionEnd: Date?
    @Binding var selectedSliceIDs: Set<UUID>

    @EnvironmentObject private var trackingEngine: TrackingEngine

    var body: some View {
        DayTimelineView(
            slices: slices,
            projects: projects,
            day: day,
            selectionStart: $selectionStart,
            selectionEnd: $selectionEnd,
            selectedSliceIDs: $selectedSliceIDs,
            onAssignSelection: assignSelection
        )
        .frame(height: height)
    }

    private func assignSelection(start: Date, end: Date, project: Project?) {
        let targets: [TimelineSlice]
        if !selectedSliceIDs.isEmpty {
            targets = slices.filter { selectedSliceIDs.contains($0.id) }
        } else {
            targets = slices.filter { $0.end > start && $0.start < end }
        }
        for slice in targets {
            let rangeStart: Date
            let rangeEnd: Date
            if selectedSliceIDs.isEmpty {
                rangeStart = max(start, slice.start)
                rangeEnd = min(end, slice.end)
            } else {
                rangeStart = slice.start
                rangeEnd = slice.end
            }
            if let project {
                trackingEngine.splitAndAssign(
                    segment: slice.segment,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    to: project
                )
            } else {
                trackingEngine.splitAndUnassign(
                    segment: slice.segment,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                )
            }
        }
        selectionStart = nil
        selectionEnd = nil
        selectedSliceIDs = []
    }
}
