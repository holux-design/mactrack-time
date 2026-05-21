import SwiftUI
import SwiftData

struct SegmentRowView: View {
    let slice: TimelineSlice
    let projects: [Project]

    private var project: Project? {
        guard let id = slice.segment.projectID else { return nil }
        return projects.first { $0.id == id }
    }

    /// Human-readable subtitle: window title if available, otherwise URL domain.
    private var subtitle: String? {
        if !slice.segment.windowTitle.isEmpty { return slice.segment.windowTitle }
        if !slice.segment.url.isEmpty,
           let host = URL(string: slice.segment.url)?.host {
            return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
        return nil
    }

    /// Small URL tag shown when we have a URL but no window title.
    private var urlDomain: String? {
        guard slice.segment.windowTitle.isEmpty,
              !slice.segment.url.isEmpty,
              let host = URL(string: slice.segment.url)?.host else { return nil }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(bundleIdentifier: slice.segment.bundleIdentifier, size: 24)
            RoundedRectangle(cornerRadius: 2)
                .fill(project.map { ProjectColors.color(from: $0.colorHex) } ?? Color.secondary.opacity(0.4))
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(slice.segment.appName)
                    .font(.subheadline.weight(.medium))
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(project?.name ?? "Untracked")
                    .font(.caption)
                    .foregroundStyle(project == nil ? .secondary : .primary)
                Text(DurationFormatting.short(slice.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct OverviewView: View {
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TimeSegment.startDate) private var segments: [TimeSegment]

    @EnvironmentObject private var focusTracker: WindowFocusTracker

    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var selectionStart: Date?
    @State private var selectionEnd: Date?
    @State private var selectedSliceIDs: Set<UUID> = []

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDay)
    }

    private var daySlices: [TimelineSlice] {
        DayTimeline.slices(from: segments, on: selectedDay)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                projectSummary
                timelineBar
                activityList
            }
            .padding(24)
        }
        .frostedGlassContent()
        .navigationTitle("Overview")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                DayNavigationControl(day: $selectedDay)
                    .padding(.trailing, 10)
                    .offset(x: 2, y: -2)
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedDay, format: .dateTime.weekday(.wide).month().day().year())
                .font(.title2.weight(.semibold))
            if isToday {
                HStack(spacing: 6) {
                    AppIconView(
                        bundleIdentifier: focusTracker.currentWindow.bundleIdentifier,
                        size: 18
                    )
                    Text("Focused: \(focusTracker.currentWindow.appName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var projectSummary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            summaryCard(
                title: "Untracked",
                duration: DayTimeline.duration(for: nil, segments: segments, on: selectedDay),
                color: .secondary.opacity(0.5)
            )
            ForEach(projects) { project in
                summaryCard(
                    title: project.name,
                    duration: DayTimeline.duration(for: project.id, segments: segments, on: selectedDay),
                    color: ProjectColors.color(from: project.colorHex)
                )
            }
        }
    }

    private func summaryCard(title: String, duration: TimeInterval, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            Text(DurationFormatting.tile(duration))
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var timelineBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline")
                .font(.headline)
            DayTimelineSection(
                slices: daySlices,
                projects: projects,
                day: selectedDay,
                selectionStart: $selectionStart,
                selectionEnd: $selectionEnd,
                selectedSliceIDs: $selectedSliceIDs
            )
        }
    }

    private var activityList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Activity")
                .font(.headline)
            if daySlices.isEmpty {
                ContentUnavailableView(
                    "No activity",
                    systemImage: "clock",
                    description: Text("\(AppIdentity.displayName) records time whenever a window is focused.")
                )
                .frame(maxWidth: .infinity, minHeight: 160)
            } else {
                ForEach(daySlices.reversed().prefix(40)) { slice in
                    SegmentRowView(slice: slice, projects: projects)
                }
            }
        }
    }
}
