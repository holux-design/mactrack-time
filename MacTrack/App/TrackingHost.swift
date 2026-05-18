import SwiftData
import SwiftUI

struct TrackingHost<Content: View>: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var session: TrackingSession

    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if session.engine != nil {
                content()
                    .environmentObject(session.engine!)
                    .environmentObject(session.focusTracker)
            } else {
                MenuBarPlaceholderView()
            }
        }
        .task {
            session.configure(modelContext: modelContext)
        }
    }
}
