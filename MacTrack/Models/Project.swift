import Foundation
import SwiftData

@Model
final class Project {
    private static let keywordSeparator = "\u{1E}"

    var id: UUID
    var name: String
    var colorHex: String
    var keywordList: String?
    var keywords: [String]
    var createdAt: Date
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \ProjectKeyword.project)
    var keywordEntries: [ProjectKeyword]

    init(
        name: String,
        colorHex: String = "#5B8DEF",
        keywords: [String] = [],
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.keywords = keywords
        self.keywordList = Self.encodeKeywords(keywords)
        self.createdAt = Date()
        self.sortOrder = sortOrder
        self.keywordEntries = keywords
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { ProjectKeyword(text: $0) }
    }

    // MARK: - Keywords

    func keywordValues() -> [String] {
        ensureKeywordEntriesLoaded()
        return keywordEntries
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func addKeyword(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        ensureKeywordEntriesLoaded()
        let exists = keywordEntries.contains {
            $0.text.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !exists else { return }
        keywordEntries.append(ProjectKeyword(text: trimmed))
        syncLegacyKeywordFields()
    }

    func removeKeyword(_ value: String) {
        ensureKeywordEntriesLoaded()
        keywordEntries.removeAll { $0.text == value }
        syncLegacyKeywordFields()
    }

    func ensureKeywordEntriesLoaded() {
        guard keywordEntries.isEmpty else { return }
        if let keywordList, !keywordList.isEmpty {
            for text in Self.decodeKeywords(keywordList) {
                keywordEntries.append(ProjectKeyword(text: text))
            }
            return
        }
        for text in keywords where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keywordEntries.append(ProjectKeyword(text: text))
        }
    }

    func syncLegacyKeywordFields() {
        let values = keywordValues()
        keywords = values
        keywordList = Self.encodeKeywords(values)
    }

    private static func encodeKeywords(_ values: [String]) -> String? {
        let encoded = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: keywordSeparator)
        return encoded.isEmpty ? nil : encoded
    }

    private static func decodeKeywords(_ storage: String) -> [String] {
        guard !storage.isEmpty else { return [] }
        return storage
            .split(separator: Character(UnicodeScalar(0x1E)!))
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
