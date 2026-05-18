import Foundation
import SwiftData

@Model
final class ProjectKeyword {
    var id: UUID
    var text: String
    var createdAt: Date
    var project: Project?

    init(text: String) {
        self.id = UUID()
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = Date()
    }
}
