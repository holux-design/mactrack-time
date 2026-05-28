import AppKit
import Combine
import Foundation
import SwiftData

@MainActor
final class TrackingEngine: ObservableObject {
    @Published private(set) var activeSegment: TimeSegment?
    @Published private(set) var currentProjectName: String?
    @Published private(set) var isTracking = false

    private let modelContext: ModelContext
    private let focusTracker: WindowFocusTracker
    private let appSettings: AppSettings
    private var switchDebounceTimer: Timer?
    private var pendingWindow: FocusedWindowInfo?

    init(
        modelContext: ModelContext,
        focusTracker: WindowFocusTracker,
        appSettings: AppSettings = .shared
    ) {
        self.modelContext = modelContext
        self.focusTracker = focusTracker
        self.appSettings = appSettings
        self.focusTracker.onFocusChange = { [weak self] window in
            Task { @MainActor in
                self?.handleFocusChange(window)
            }
        }
        NotificationCenter.default.addObserver(
            forName: .mactrackProjectsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isTracking else { return }
                self.handleFocusChange(self.focusTracker.currentWindow)
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSystemSleep() }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSystemWake() }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSystemSleep() }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstop"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleSystemWake() }
        }
    }

    func start() {
        guard !isTracking else { return }
        isTracking = true
        focusTracker.start()
        let current = focusTracker.currentWindow
        if !current.appName.isEmpty, !AppIdentity.isSelfApp(bundleIdentifier: current.bundleIdentifier) {
            openSegment(for: current)
        }
    }

    func stop() {
        guard isTracking else { return }
        isTracking = false
        cancelPendingSwitch()
        focusTracker.stop()
        closeActiveSegment()
        save()
    }

    func handleFocusChange(_ window: FocusedWindowInfo) {
        guard isTracking else { return }
        guard !window.appName.isEmpty else { return }

        if AppIdentity.isSelfApp(bundleIdentifier: window.bundleIdentifier) {
            cancelPendingSwitch()
            closeActiveSegment()
            currentProjectName = nil
            return
        }

        if let active = activeSegment,
           active.bundleIdentifier == window.bundleIdentifier {
            cancelPendingSwitch()
            openSegment(for: window)
            return
        }

        let debounce = appSettings.appSwitchDebounceSeconds
        if debounce <= 0 {
            openSegment(for: window)
            return
        }

        schedulePendingSwitch(to: window, debounce: debounce)
    }

    func resyncCurrentWindow() {
        guard isTracking else { return }
        handleFocusChange(focusTracker.currentWindow)
    }

    func assignManual(
        segmentIDs: [UUID],
        to project: Project,
        in segments: [TimeSegment]
    ) {
        let idSet = Set(segmentIDs)
        for segment in segments where idSet.contains(segment.id) {
            segment.projectID = project.id
            segment.assignmentSource = .manual
        }
        save()
    }

    func createManualSegment(start: Date, end: Date, project: Project) {
        guard end > start else { return }
        let segment = TimeSegment(
            startDate: start,
            projectID: project.id,
            windowTitle: "",
            appName: TimeSegment.manualAppName,
            bundleIdentifier: "",
            assignmentSource: .manual
        )
        segment.endDate = end
        modelContext.insert(segment)
        save()
    }

    func splitAndAssign(
        segment: TimeSegment,
        rangeStart: Date,
        rangeEnd: Date,
        to project: Project
    ) {
        splitAndSetProject(
            segment: segment,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            projectID: project.id
        )
    }

    func splitAndUnassign(
        segment: TimeSegment,
        rangeStart: Date,
        rangeEnd: Date
    ) {
        if segment.isStandaloneManualEntry {
            removeStandaloneManual(segment: segment, rangeStart: rangeStart, rangeEnd: rangeEnd)
            return
        }
        splitAndSetProject(
            segment: segment,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            projectID: nil
        )
    }

    private func removeStandaloneManual(
        segment: TimeSegment,
        rangeStart: Date,
        rangeEnd: Date
    ) {
        let segStart = segment.startDate
        let segEnd = segment.endDate ?? Date()
        let removeStart = max(rangeStart, segStart)
        let removeEnd = min(rangeEnd, segEnd)
        guard removeEnd > removeStart else { return }

        let projectID = segment.projectID

        if segment === activeSegment {
            closeActiveSegment(at: segEnd)
        }
        modelContext.delete(segment)

        if removeStart > segStart, let projectID {
            let before = TimeSegment(
                startDate: segStart,
                projectID: projectID,
                windowTitle: "",
                appName: TimeSegment.manualAppName,
                bundleIdentifier: "",
                assignmentSource: .manual
            )
            before.endDate = removeStart
            modelContext.insert(before)
        }

        if removeEnd < segEnd, let projectID {
            let after = TimeSegment(
                startDate: removeEnd,
                projectID: projectID,
                windowTitle: "",
                appName: TimeSegment.manualAppName,
                bundleIdentifier: "",
                assignmentSource: .manual
            )
            after.endDate = segEnd
            modelContext.insert(after)
        }

        save()
    }

    private func splitAndSetProject(
        segment: TimeSegment,
        rangeStart: Date,
        rangeEnd: Date,
        projectID: UUID?
    ) {
        let segStart = segment.startDate
        let segEnd = segment.endDate ?? Date()
        let assignStart = max(rangeStart, segStart)
        let assignEnd = min(rangeEnd, segEnd)
        guard assignEnd > assignStart else { return }

        let originalProject = segment.projectID
        let originalSource = segment.assignmentSource
        let meta = (
            segment.windowTitle,
            segment.appName,
            segment.bundleIdentifier
        )

        if segment === activeSegment {
            closeActiveSegment(at: segEnd)
        }
        modelContext.delete(segment)

        if assignStart > segStart {
            let before = TimeSegment(
                startDate: segStart,
                projectID: originalProject,
                windowTitle: meta.0,
                appName: meta.1,
                bundleIdentifier: meta.2,
                assignmentSource: originalSource
            )
            before.endDate = assignStart
            modelContext.insert(before)
        }

        let assigned = TimeSegment(
            startDate: assignStart,
            projectID: projectID,
            windowTitle: meta.0,
            appName: meta.1,
            bundleIdentifier: meta.2,
            assignmentSource: .manual
        )
        assigned.endDate = assignEnd
        modelContext.insert(assigned)

        if assignEnd < segEnd {
            let after = TimeSegment(
                startDate: assignEnd,
                projectID: originalProject,
                windowTitle: meta.0,
                appName: meta.1,
                bundleIdentifier: meta.2,
                assignmentSource: originalSource
            )
            after.endDate = segEnd
            modelContext.insert(after)
        }

        save()
    }

    private func schedulePendingSwitch(to window: FocusedWindowInfo, debounce: TimeInterval) {
        cancelPendingSwitch()
        pendingWindow = window
        switchDebounceTimer = Timer.scheduledTimer(withTimeInterval: debounce, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.commitPendingSwitch()
            }
        }
        if let timer = switchDebounceTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func commitPendingSwitch() {
        guard let window = pendingWindow else { return }
        pendingWindow = nil
        switchDebounceTimer = nil

        guard isTracking else { return }
        guard !AppIdentity.isSelfApp(bundleIdentifier: window.bundleIdentifier) else { return }

        let current = focusTracker.currentWindow
        guard current.bundleIdentifier == window.bundleIdentifier else { return }

        openSegment(for: window)
    }

    private func cancelPendingSwitch() {
        switchDebounceTimer?.invalidate()
        switchDebounceTimer = nil
        pendingWindow = nil
    }

    private func openSegment(for window: FocusedWindowInfo, startDate: Date = Date()) {
        guard !AppIdentity.isSelfApp(bundleIdentifier: window.bundleIdentifier) else { return }

        let projects = fetchProjects()
        let match = ProjectMatcher.explain(window: window, projects: projects)
        let matched = match.isAmbiguous ? nil : match.project
        let projectID = matched?.id
        let resolvedTitle = window.windowTitle

        if let active = activeSegment,
           active.appName == window.appName,
           active.bundleIdentifier == window.bundleIdentifier {
            let sameProject = active.projectID == projectID
            let sameTitle = active.windowTitle == resolvedTitle
            if sameProject && sameTitle {
                currentProjectName = displayName(for: match, matched: matched)
                return
            }
            if sameProject {
                active.windowTitle = resolvedTitle
                currentProjectName = displayName(for: match, matched: matched)
                save()
                return
            }
            active.windowTitle = resolvedTitle
            active.projectID = projectID
            active.assignmentSource = .automatic
            currentProjectName = displayName(for: match, matched: matched)
            save()
            return
        }

        closeActiveSegment(at: startDate)

        let segment = TimeSegment(
            startDate: startDate,
            projectID: projectID,
            windowTitle: resolvedTitle,
            url: window.url,
            appName: window.appName,
            bundleIdentifier: window.bundleIdentifier,
            assignmentSource: .automatic
        )
        modelContext.insert(segment)
        activeSegment = segment
        currentProjectName = displayName(for: match, matched: matched)
        save()
    }

    private func displayName(for match: KeywordMatchExplanation, matched: Project?) -> String? {
        if match.isAmbiguous {
            return "Ambiguous"
        }
        return matched?.name
    }

    private func handleSystemSleep() {
        guard isTracking else { return }
        cancelPendingSwitch()
        closeActiveSegment()
        focusTracker.stop()
        save()
    }

    private func handleSystemWake() {
        guard isTracking else { return }
        focusTracker.start()
        let current = focusTracker.currentWindow
        if !current.appName.isEmpty, !AppIdentity.isSelfApp(bundleIdentifier: current.bundleIdentifier) {
            openSegment(for: current)
        }
    }

    private func closeActiveSegment(at date: Date = Date()) {
        activeSegment?.close(at: date)
        activeSegment = nil
        currentProjectName = nil
    }

    private func fetchProjects() -> [Project] {
        ProjectStore.fetchAll(from: modelContext)
    }

    private func save() {
        try? modelContext.save()
    }
}
