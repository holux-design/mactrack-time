import Foundation

struct TimelineSlice: Identifiable {
    let id: UUID
    let segment: TimeSegment
    let start: Date
    let end: Date

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

enum TimelineSnapInterval: String, CaseIterable, Identifiable {
    case hour
    case halfHour
    case quarterHour
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hour: "Hour"
        case .halfHour: "Half hour"
        case .quarterHour: "Quarter hour"
        case .none: "None"
        }
    }

    fileprivate var snapSeconds: TimeInterval? {
        switch self {
        case .hour: 3600
        case .halfHour: 1800
        case .quarterHour: 900
        case .none: nil
        }
    }
}

enum TimelineTickKind: Hashable {
    case hour
    case halfHour
    case quarterHour
}

struct TimelineTick: Hashable, Identifiable {
    let date: Date
    let kind: TimelineTickKind

    var id: TimeInterval { date.timeIntervalSince1970 }
}

extension TimelineTickKind {
    var markerHeight: CGFloat {
        switch self {
        case .hour: 6
        case .halfHour, .quarterHour: 4
        }
    }

    var markerOpacity: Double {
        switch self {
        case .hour: 0.35
        case .halfHour, .quarterHour: 0.22
        }
    }

    var gridOpacity: Double {
        switch self {
        case .hour: 0.12
        case .halfHour, .quarterHour: 0.08
        }
    }
}

enum DayTimeline {
    /// Pixels between half-hour ticks before they appear.
    static let halfHourMarkerMinSpacing: CGFloat = 42
    /// Pixels between quarter-hour ticks before they appear.
    static let quarterHourMarkerMinSpacing: CGFloat = 24

    static func markerTicks(
        for day: Date,
        zoom: CGFloat,
        viewportWidth: CGFloat,
        calendar: Calendar = .current
    ) -> [TimelineTick] {
        let (dayStart, dayEnd) = dayBounds(for: day, calendar: calendar)
        let clampedZoom = min(max(zoom, 1), 48)
        let pixelsPerHour = viewportWidth * clampedZoom / 24
        let showHalfHours = pixelsPerHour / 2 >= halfHourMarkerMinSpacing
        let showQuarterHours = pixelsPerHour / 4 >= quarterHourMarkerMinSpacing

        guard let firstQuarter = alignedQuarterHour(onOrAfter: dayStart, calendar: calendar) else {
            return []
        }

        var ticks: [TimelineTick] = []
        var current = firstQuarter
        while current < dayEnd {
            if current >= dayStart, let kind = tickKind(for: current, calendar: calendar) {
                switch kind {
                case .hour:
                    ticks.append(TimelineTick(date: current, kind: .hour))
                case .halfHour where showHalfHours:
                    ticks.append(TimelineTick(date: current, kind: .halfHour))
                case .quarterHour where showQuarterHours:
                    ticks.append(TimelineTick(date: current, kind: .quarterHour))
                default:
                    break
                }
            }
            guard let next = calendar.date(byAdding: .minute, value: 15, to: current) else { break }
            current = next
        }
        return ticks
    }

    private static func alignedQuarterHour(onOrAfter date: Date, calendar: Calendar) -> Date? {
        guard let hourStart = calendar.dateInterval(of: .hour, for: date)?.start else { return nil }
        var current = hourStart
        while current < date {
            guard let next = calendar.date(byAdding: .minute, value: 15, to: current) else { return nil }
            current = next
        }
        return current
    }

    private static func tickKind(for date: Date, calendar: Calendar) -> TimelineTickKind? {
        let minute = calendar.component(.minute, from: date)
        switch minute {
        case 0: return .hour
        case 30: return .halfHour
        case 15, 45: return .quarterHour
        default: return nil
        }
    }

    static func snappedDate(
        _ date: Date,
        on day: Date,
        interval: TimelineSnapInterval,
        calendar: Calendar = .current
    ) -> Date {
        guard let snapSeconds = interval.snapSeconds else { return date }

        let (dayStart, dayEnd) = dayBounds(for: day, calendar: calendar)
        let clamped = min(max(date, dayStart), dayEnd)
        let offset = clamped.timeIntervalSince(dayStart)
        let snappedOffset = min((offset / snapSeconds).rounded() * snapSeconds, dayEnd.timeIntervalSince(dayStart))
        return dayStart.addingTimeInterval(snappedOffset)
    }

    static func snappedSelection(
        start: Date,
        end: Date,
        on day: Date,
        interval: TimelineSnapInterval,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        guard interval != .none else {
            return (min(start, end), max(start, end))
        }

        let orderedStart = min(start, end)
        let orderedEnd = max(start, end)
        var snappedStart = snappedDate(orderedStart, on: day, interval: interval, calendar: calendar)
        var snappedEnd = snappedDate(orderedEnd, on: day, interval: interval, calendar: calendar)

        if snappedEnd <= snappedStart, let snapSeconds = interval.snapSeconds {
            let (dayStart, dayEnd) = dayBounds(for: day, calendar: calendar)
            snappedEnd = min(
                dayStart.addingTimeInterval(snappedStart.timeIntervalSince(dayStart) + snapSeconds),
                dayEnd
            )
        }

        return (snappedStart, snappedEnd)
    }

    static func dayBounds(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        return (start, end)
    }

    static func slices(
        from segments: [TimeSegment],
        on date: Date,
        calendar: Calendar = .current
    ) -> [TimelineSlice] {
        let (dayStart, dayEnd) = dayBounds(for: date, calendar: calendar)
        return segments
            .filter { !AppIdentity.isSelfApp(bundleIdentifier: $0.bundleIdentifier) }
            .compactMap { segment in
            let end = segment.endDate ?? Date()
            let start = max(segment.startDate, dayStart)
            let clippedEnd = min(end, dayEnd)
            guard clippedEnd > start else { return nil }
            return TimelineSlice(
                id: segment.id,
                segment: segment,
                start: start,
                end: clippedEnd
            )
        }
        .sorted { $0.start < $1.start }
    }

    static func duration(
        for projectID: UUID?,
        segments: [TimeSegment],
        on date: Date,
        calendar: Calendar = .current
    ) -> TimeInterval {
        slices(from: segments, on: date, calendar: calendar)
            .filter { $0.segment.projectID == projectID }
            .reduce(0) { $0 + $1.duration }
    }
}
