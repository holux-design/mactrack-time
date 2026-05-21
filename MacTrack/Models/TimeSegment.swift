import Foundation
import SwiftData

enum AssignmentSource: String, Codable {
    case automatic
    case manual
}

@Model
final class TimeSegment {
    static let manualAppName = "Manual"

    var id: UUID
    var startDate: Date
    var endDate: Date?
    var projectID: UUID?
    var windowTitle: String
    var url: String
    var appName: String
    var bundleIdentifier: String
    var assignmentSourceRaw: String

    var assignmentSource: AssignmentSource {
        get { AssignmentSource(rawValue: assignmentSourceRaw) ?? .automatic }
        set { assignmentSourceRaw = newValue.rawValue }
    }

    var isActive: Bool { endDate == nil }

    var duration: TimeInterval {
        let end = endDate ?? Date()
        return max(0, end.timeIntervalSince(startDate))
    }

    var isUntracked: Bool { projectID == nil }

    /// Gap-filled timeline entry (no real app/window), not a manually reassigned slice of tracked time.
    var isStandaloneManualEntry: Bool {
        assignmentSource == .manual
            && bundleIdentifier.isEmpty
            && appName == Self.manualAppName
    }

    init(
        startDate: Date = Date(),
        projectID: UUID? = nil,
        windowTitle: String = "",
        url: String = "",
        appName: String = "",
        bundleIdentifier: String = "",
        assignmentSource: AssignmentSource = .automatic
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = nil
        self.projectID = projectID
        self.windowTitle = windowTitle
        self.url = url
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.assignmentSourceRaw = assignmentSource.rawValue
    }

    func close(at date: Date = Date()) {
        endDate = date
    }
}
