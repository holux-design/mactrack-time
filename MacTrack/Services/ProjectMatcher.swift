import Foundation

struct KeywordMatchExplanation {
    let project: Project?
    let keyword: String?
    let isAmbiguous: Bool
    let candidateProjects: [Project]

    var summary: String {
        if isAmbiguous {
            return "Ambiguous: \(candidateProjects.map(\.name).joined(separator: ", "))"
        }
        guard let project, let keyword else {
            return "No keyword matched in window title"
        }
        return "\(project.name) via “\(keyword)”"
    }
}

enum ProjectMatcher {
    static func match(window: FocusedWindowInfo, projects: [Project]) -> Project? {
        resolve(window: window, projects: projects)?.project
    }

    static func explain(window: FocusedWindowInfo, projects: [Project]) -> KeywordMatchExplanation {
        guard let result = resolve(window: window, projects: projects) else {
            return KeywordMatchExplanation(
                project: nil, keyword: nil, isAmbiguous: false, candidateProjects: []
            )
        }

        if result.isAmbiguous {
            return KeywordMatchExplanation(
                project: nil, keyword: result.keyword, isAmbiguous: true,
                candidateProjects: result.tiedProjects
            )
        }

        return KeywordMatchExplanation(
            project: result.project,
            keyword: result.keyword,
            isAmbiguous: false,
            candidateProjects: result.project.map { [$0] } ?? []
        )
    }

    // MARK: - Private

    private struct MatchResult {
        let project: Project?
        let keyword: String?
        let isAmbiguous: Bool
        let tiedProjects: [Project]
    }

    private struct KeywordHit {
        let project: Project
        let keyword: String
        let keywordLength: Int
    }

    private static func resolve(window: FocusedWindowInfo, projects: [Project]) -> MatchResult? {
        let title = normalized(window.windowTitle)
        guard !title.isEmpty else { return nil }

        var hits: [KeywordHit] = []
        for project in projects {
            project.ensureKeywordEntriesLoaded()
            for keyword in project.keywordValues() {
                let needle = normalized(keyword)
                guard !needle.isEmpty, title.contains(needle) else { continue }
                hits.append(KeywordHit(
                    project: project,
                    keyword: keyword,
                    keywordLength: needle.count
                ))
            }
        }

        guard !hits.isEmpty else { return nil }

        let maxLength = hits.map(\.keywordLength).max() ?? 0
        let bestHits = hits.filter { $0.keywordLength == maxLength }
        let tiedProjects = Array(Set(bestHits.map(\.project)))
            .sorted { $0.sortOrder < $1.sortOrder }

        guard let winner = bestHits.sorted(by: { lhs, rhs in
            if lhs.project.sortOrder != rhs.project.sortOrder {
                return lhs.project.sortOrder < rhs.project.sortOrder
            }
            return lhs.keyword.localizedCaseInsensitiveCompare(rhs.keyword) == .orderedAscending
        }).first else {
            return nil
        }

        let isAmbiguous = tiedProjects.count > 1
        return MatchResult(
            project: winner.project,
            keyword: winner.keyword,
            isAmbiguous: isAmbiguous,
            tiedProjects: tiedProjects
        )
    }

    /// Case-insensitive, diacritic-insensitive comparison string for window titles and keywords.
    private static func normalized(_ text: String) -> String {
        text
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{00AD}", with: "")
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }
}
