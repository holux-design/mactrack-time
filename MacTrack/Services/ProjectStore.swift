import Foundation
import SwiftData

enum ProjectStore {
    static func fetchAll(from modelContext: ModelContext) -> [Project] {
        modelContext.processPendingChanges()
        let descriptor = FetchDescriptor<Project>(sortBy: [SortDescriptor(\.sortOrder)])
        let projects = (try? modelContext.fetch(descriptor)) ?? []
        var changed = false
        for project in projects {
            let before = project.keywordEntries.count
            project.ensureKeywordEntriesLoaded()
            if project.keywordEntries.count != before {
                project.syncLegacyKeywordFields()
                changed = true
            }
        }
        if changed {
            try? modelContext.save()
        }
        return projects
    }

    static func migrateAllKeywords(in modelContext: ModelContext) {
        _ = fetchAll(from: modelContext)
    }
}
