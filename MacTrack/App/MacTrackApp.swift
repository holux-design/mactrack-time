import SwiftData
import SwiftUI

@main
struct MacTrackApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var appSettings = AppSettings.shared
    @StateObject private var session: TrackingSession

    private let sharedModelContainer: ModelContainer

    init() {
        let container = ModelContainerFactory.make()
        let trackingSession = TrackingSession()
        sharedModelContainer = container
        _session = StateObject(wrappedValue: trackingSession)
        MacTrackAppContext.modelContainer = container
        MacTrackAppContext.session = trackingSession
    }

    var body: some Scene {
        MenuBarExtra(AppIdentity.displayName, systemImage: "clock.fill") {
            TrackingHost {
                MenuBarView()
            }
            .environmentObject(appState)
            .environmentObject(appSettings)
            .environmentObject(session)
        }
        .menuBarExtraStyle(.window)
        .modelContainer(sharedModelContainer)

        WindowGroup(id: "main") {
            TrackingHost {
                MainDashboardView()
            }
            .environmentObject(appState)
            .environmentObject(appSettings)
            .environmentObject(session)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 900, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
