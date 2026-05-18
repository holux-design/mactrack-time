import SwiftData
import SwiftUI

@MainActor
enum MacTrackAppContext {
    static var session: TrackingSession?
    static var modelContainer: ModelContainer?

    static func bootstrapTracking() {
        guard let session, let modelContainer else { return }
        session.configure(modelContext: modelContainer.mainContext)
    }
}
