import SwiftUI
import SwiftData

struct UntrackedTimelineView: View {
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TimeSegment.startDate) private var segments: [TimeSegment]

    @State private var selectedDay = Date()
    @State private var selectionStart: Date?
    @State private var selectionEnd: Date?
    @State private var selectedSliceIDs: Set<UUID> = []

    private var daySlices: [TimelineSlice] {
        DayTimeline.slices(from: segments, on: selectedDay)
    }

    private var untrackedSlices: [TimelineSlice] {
        daySlices.filter { $0.segment.projectID == nil }
    }

    private var untrackedDuration: TimeInterval {
        untrackedSlices.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                timelineSection
                untrackedList
            }
            .padding(24)
        }
        .frostedGlassContent()
        .navigationTitle("Untracked")
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
        VStack(alignment: .leading, spacing: 6) {
            Text("\(DurationFormatting.clock(untrackedDuration)) untracked")
                .font(.title2.weight(.semibold))
            Text("Left-click a block to select it, or drag to select a range. Right-click the selection to assign a project.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var timelineSection: some View {
        DayTimelineSection(
            slices: daySlices,
            projects: projects,
            day: selectedDay,
            height: 120,
            selectionStart: $selectionStart,
            selectionEnd: $selectionEnd,
            selectedSliceIDs: $selectedSliceIDs
        )
        .padding(14)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    private var untrackedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Untracked blocks")
                .font(.headline)
            if untrackedSlices.isEmpty {
                ContentUnavailableView(
                    "All tracked",
                    systemImage: "checkmark.circle",
                    description: Text("No untracked time on this day.")
                )
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                ForEach(untrackedSlices.reversed()) { slice in
                    HStack {
                        SegmentRowView(slice: slice, projects: projects)
                        Button("Select") {
                            selectionStart = slice.start
                            selectionEnd = slice.end
                            selectedSliceIDs = []
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }
}
