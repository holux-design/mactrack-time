import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: MainTab = .today

    enum MainTab: String, CaseIterable, Identifiable {
        case today
        case untracked
        case projects
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .today: "Today"
            case .untracked: "Untracked"
            case .projects: "Projects"
            case .settings: "Settings"
            }
        }

        var icon: String {
            switch self {
            case .today: "chart.bar.fill"
            case .untracked: "timeline.selection"
            case .projects: "folder.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

}
