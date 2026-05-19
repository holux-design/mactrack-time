import Combine
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: MainTab = .overview

    enum MainTab: String, CaseIterable, Identifiable {
        case overview
        case projects
        case settings

        var id: String { rawValue }

        var title: String {
            switch self {
            case .overview: "Overview"
            case .projects: "Projects"
            case .settings: "Settings"
            }
        }

        var icon: String {
            switch self {
            case .overview: "chart.bar.fill"
            case .projects: "folder.fill"
            case .settings: "gearshape.fill"
            }
        }
    }

}
