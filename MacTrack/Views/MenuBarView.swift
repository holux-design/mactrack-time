import AppKit
import SwiftData
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var trackingEngine: TrackingEngine
    @EnvironmentObject private var focusTracker: WindowFocusTracker

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.sortOrder) private var projects: [Project]
    @Query(sort: \TimeSegment.startDate, order: .reverse) private var segments: [TimeSegment]

    var body: some View {
        ScrollView {
            popoverContent
        }
        .frostedGlassContent()
        .frame(width: 320)
        .frame(maxHeight: 520)
        .frostedGlassWindow()
        .onAppear {
            ProjectStore.migrateAllKeywords(in: modelContext)
            trackingEngine.resyncCurrentWindow()
        }
        .onChange(of: projects.map(\.id)) { _, _ in
            trackingEngine.resyncCurrentWindow()
        }
        .onChange(of: keywordFingerprint) { _, _ in
            trackingEngine.resyncCurrentWindow()
        }
    }

    private var popoverContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.tint)
                Text(AppIdentity.displayName)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(trackingEngine.isTracking ? .green : .secondary)
                    .frame(width: 8, height: 8)
            }

            GroupBox("Focused window") {
                VStack(alignment: .leading, spacing: 8) {
                    appFocusRow
                    titleRow
                    suggestedProjectRow
                    trackingProjectRow
                    if let active = trackingEngine.activeSegment {
                        HStack {
                            Text("Session")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 64, alignment: .leading)
                            Text(DurationFormatting.short(active.duration))
                                .font(.caption.monospacedDigit())
                            Spacer()
                        }
                    }
                }
            }

            if focusTracker.accessibilityGranted,
               !focusTracker.screenCaptureGranted,
               focusTracker.currentWindow.windowTitle.isEmpty,
               !focusTracker.currentWindow.appName.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "record.circle")
                        .foregroundStyle(.orange)
                    Text("Enable Screen Recording so \(AppIdentity.displayName) can read window titles from more apps.")
                        .font(.caption)
                    Spacer()
                    Button("Open Settings") {
                        focusTracker.openScreenCaptureSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !focusTracker.accessibilityGranted {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.orange)
                        Text("Accessibility is required to read window titles.")
                            .font(.caption)
                        Spacer()
                        Button("Open Settings") {
                            focusTracker.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Text("\(AppIdentity.displayName) should appear in the list after you click Open Settings. If it does not, press +, choose \(AppIdentity.displayName), or navigate to:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(Bundle.main.bundlePath)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
            }

            Divider()

            ForEach(projects) { project in
                HStack {
                    Circle()
                        .fill(ProjectColors.color(from: project.colorHex))
                        .frame(width: 8, height: 8)
                    Text(project.name)
                    Spacer()
                    Text(DurationFormatting.short(todayDuration(for: project.id)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if projects.isEmpty {
                Text("Add projects and keywords to start auto-sorting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                Spacer()
                Button("Open \(AppIdentity.displayName)") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var titlePlaceholder: String {
        if !focusTracker.accessibilityGranted {
            return "Enable Accessibility for titles"
        }
        if !focusTracker.screenCaptureGranted {
            return "Enable Screen Recording if titles stay empty"
        }
        return "No title available"
    }

    private var loadedProjects: [Project] {
        ProjectStore.fetchAll(from: modelContext)
    }

    private var keywordFingerprint: String {
        loadedProjects
            .map { project in
                let keys = project.keywordValues().joined(separator: ",")
                return "\(project.id.uuidString):\(keys)"
            }
            .joined(separator: "|")
    }

    private var matchExplanation: KeywordMatchExplanation {
        ProjectMatcher.explain(window: focusTracker.currentWindow, projects: loadedProjects)
    }

    @ViewBuilder
    private var trackingProjectRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("Tracking")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(trackingEngine.currentProjectName ?? "Untracked")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(trackingEngine.currentProjectName == nil ? .secondary : .primary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var suggestedProjectRow: some View {
        let explanation = matchExplanation
        HStack(alignment: .top, spacing: 8) {
            Text("Suggested")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if let project = explanation.project {
                        Circle()
                            .fill(ProjectColors.color(from: project.colorHex))
                            .frame(width: 8, height: 8)
                    }
                    Text(suggestedLabel(for: explanation))
                        .font(.subheadline.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(explanation.summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func suggestedLabel(for explanation: KeywordMatchExplanation) -> String {
        if let project = explanation.project {
            return project.name
        }
        if explanation.isAmbiguous {
            return explanation.candidateProjects.map(\.name).joined(separator: ", ")
        }
        return "Untracked"
    }

    @ViewBuilder
    private var titleRow: some View {
        let title = focusTracker.currentWindow.windowTitle
        HStack(alignment: .top, spacing: 8) {
            Text("Title")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            Text(title.isEmpty ? titlePlaceholder : title)
                .font(.subheadline)
                .foregroundStyle(title.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var appFocusRow: some View {
        let window = focusTracker.currentWindow
        HStack(alignment: .top, spacing: 8) {
            Text("App")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)
            AppIconView(bundleIdentifier: window.bundleIdentifier, size: 22)
            Text(window.appName.isEmpty ? "No focused app" : window.appName)
                .font(.subheadline)
                .foregroundStyle(window.appName.isEmpty ? .secondary : .primary)
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func todayDuration(for projectID: UUID) -> TimeInterval {
        DayTimeline.duration(
            for: projectID,
            segments: segments,
            on: Date()
        )
    }
}
