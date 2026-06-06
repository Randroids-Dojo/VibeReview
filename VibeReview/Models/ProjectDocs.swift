import Foundation

enum ProjectDocsKind: String, Codable, Equatable {
    case fullSpiralHTML
    case partialSpiralHTML
    case legacyMarkdown
    case legacyUppercaseDocs
    case none
}

struct ProjectDocsProfile: Codable, Equatable {
    var projectRootPath: String
    var docsDirectoryPath: String
    var kind: ProjectDocsKind
    var hasFollowupsHTML: Bool
    var hasOpenQuestionsHTML: Bool
    var hasPlaytestHTML: Bool
    var hasFunFactorHTML: Bool
    var hasLegacyMarkdown: Bool

    var canMutateHTMLLedgers: Bool {
        kind == .fullSpiralHTML || kind == .partialSpiralHTML || kind == .none
    }

    var usesUppercaseDocs: Bool {
        kind == .legacyUppercaseDocs
    }
}
