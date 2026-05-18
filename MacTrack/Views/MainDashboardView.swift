import SwiftUI

struct MainDashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            List(AppState.MainTab.allCases, selection: $appState.selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 180, max: 180)
            .frostedGlassContent()
        } detail: {
            switch appState.selectedTab {
            case .today:
                TodayView()
            case .untracked:
                UntrackedTimelineView()
            case .projects:
                ProjectsSettingsView()
            case .settings:
                SettingsView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 820, minHeight: 520)
        .frostedGlassWindow()
        .background(MainWindowDockTracker())
    }
}
