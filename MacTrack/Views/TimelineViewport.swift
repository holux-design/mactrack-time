import SwiftUI

struct TimelineViewport {
    var zoom: CGFloat = Self.defaultZoom
    var scrollOffset: CGFloat = 0

    static let minZoom: CGFloat = 1
    static let maxZoom: CGFloat = 48

    /// Default visible window: 7:00 through 18:00 (6 p.m.) on a 24-hour day.
    static let defaultVisibleStartHour = 7
    static let defaultVisibleEndHour = 18

    private static var defaultVisibleHours: CGFloat {
        CGFloat(defaultVisibleEndHour - defaultVisibleStartHour)
    }

    static var defaultZoom: CGFloat {
        24 / defaultVisibleHours
    }

    static func defaultScrollOffset(viewportWidth: CGFloat) -> CGFloat {
        let contentWidth = viewportWidth * defaultZoom
        return contentWidth * CGFloat(defaultVisibleStartHour) / 24
    }

    mutating func applyWorkDayDefault(viewportWidth: CGFloat) {
        guard viewportWidth > 0 else { return }
        zoom = Self.defaultZoom
        scrollOffset = Self.defaultScrollOffset(viewportWidth: viewportWidth)
        clampScrollOffset(viewportWidth: viewportWidth)
    }

    func contentWidth(for viewportWidth: CGFloat) -> CGFloat {
        viewportWidth * clampedZoom
    }

    var clampedZoom: CGFloat {
        min(max(zoom, Self.minZoom), Self.maxZoom)
    }

    mutating func clampScrollOffset(viewportWidth: CGFloat) {
        let content = contentWidth(for: viewportWidth)
        let maxOffset = max(0, content - viewportWidth)
        scrollOffset = min(max(0, scrollOffset), maxOffset)
    }

    mutating func zoom(by factor: CGFloat, at viewportX: CGFloat, viewportWidth: CGFloat) {
        let oldContentWidth = contentWidth(for: viewportWidth)
        let anchorContentX = scrollOffset + viewportX
        let anchorFraction = oldContentWidth > 0 ? anchorContentX / oldContentWidth : 0

        zoom = min(max(zoom * factor, Self.minZoom), Self.maxZoom)
        let newContentWidth = contentWidth(for: viewportWidth)
        scrollOffset = anchorFraction * newContentWidth - viewportX
        clampScrollOffset(viewportWidth: viewportWidth)
    }

    mutating func pan(by deltaX: CGFloat, viewportWidth: CGFloat) {
        scrollOffset -= deltaX
        clampScrollOffset(viewportWidth: viewportWidth)
    }
}
