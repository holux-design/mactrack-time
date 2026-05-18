import Combine
import SwiftData
import SwiftUI

@MainActor
final class TrackingSession: ObservableObject {
    let focusTracker = WindowFocusTracker()
    @Published private(set) var engine: TrackingEngine?

    func configure(modelContext: ModelContext) {
        guard engine == nil else { return }

        ProjectStore.migrateAllKeywords(in: modelContext)
        seedDefaultsIfNeeded(modelContext: modelContext)
        let engine = TrackingEngine(modelContext: modelContext, focusTracker: focusTracker)
        self.engine = engine
        engine.start()
    }

    private func seedDefaultsIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Project>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        modelContext.insert(Project(
            name: "Work",
            colorHex: "#5B8DEF",
            keywords: ["xcode", "terminal", "github"],
            sortOrder: 0
        ))
        modelContext.insert(Project(
            name: "Personal",
            colorHex: "#34C759",
            keywords: ["safari", "messages", "spotify"],
            sortOrder: 1
        ))
        try? modelContext.save()
    }
}
