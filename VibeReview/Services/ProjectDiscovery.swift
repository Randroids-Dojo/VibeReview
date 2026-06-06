import Foundation

enum ProjectDiscovery {
    private static let rootMarkers = [
        ".git",
        "AGENTS.md",
        "CLAUDE.md",
        "package.json",
        "project.godot",
        "Cargo.toml",
        "Package.swift"
    ]

    static func locateProjectRoot(from selectedURL: URL, fileManager: FileManager = .default) -> URL {
        var candidate = selectedURL.standardizedFileURL
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory), !isDirectory.boolValue {
            candidate.deleteLastPathComponent()
        }

        var current = candidate
        while true {
            if rootMarkers.contains(where: { marker in
                fileManager.fileExists(atPath: current.appendingPathComponent(marker).path)
            }) {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                return candidate
            }
            current = parent
        }
    }

    static func detectDocs(for projectRoot: URL, fileManager: FileManager = .default) -> ProjectDocsProfile {
        let lowercaseDocs = projectRoot.appendingPathComponent("docs", isDirectory: true)
        let uppercaseDocs = projectRoot.appendingPathComponent("Docs", isDirectory: true)
        let docsURL: URL
        if fileManager.fileExists(atPath: lowercaseDocs.path) {
            docsURL = lowercaseDocs
        } else if fileManager.fileExists(atPath: uppercaseDocs.path) {
            docsURL = uppercaseDocs
        } else {
            docsURL = lowercaseDocs
        }

        let followupsHTML = lowercaseDocs.appendingPathComponent("FOLLOWUPS.html")
        let questionsHTML = lowercaseDocs.appendingPathComponent("OPEN_QUESTIONS.html")
        let playtestHTML = lowercaseDocs.appendingPathComponent("PLAYTEST.html")
        let funHTML = lowercaseDocs.appendingPathComponent("FUN_FACTOR_AUDIT.html")
        let gddIndexHTML = lowercaseDocs.appendingPathComponent("gdd/index.html")

        let hasFollowupsHTML = fileManager.fileExists(atPath: followupsHTML.path)
        let hasOpenQuestionsHTML = fileManager.fileExists(atPath: questionsHTML.path)
        let hasPlaytestHTML = fileManager.fileExists(atPath: playtestHTML.path)
        let hasFunFactorHTML = fileManager.fileExists(atPath: funHTML.path)
        let hasGDDIndexHTML = fileManager.fileExists(atPath: gddIndexHTML.path)

        let legacyMarkdownFiles = [
            lowercaseDocs.appendingPathComponent("FOLLOWUPS.md"),
            lowercaseDocs.appendingPathComponent("OPEN_QUESTIONS.md"),
            lowercaseDocs.appendingPathComponent("PLAYTEST.md"),
            lowercaseDocs.appendingPathComponent("GDD.md")
        ]
        let hasLegacyMarkdown = legacyMarkdownFiles.contains { fileManager.fileExists(atPath: $0.path) }
        let uppercaseExists = fileManager.fileExists(atPath: uppercaseDocs.path)

        let kind: ProjectDocsKind
        if hasFollowupsHTML && hasOpenQuestionsHTML && hasPlaytestHTML && hasFunFactorHTML {
            kind = .fullSpiralHTML
        } else if hasFollowupsHTML || hasOpenQuestionsHTML || hasPlaytestHTML || hasFunFactorHTML || hasGDDIndexHTML {
            kind = .partialSpiralHTML
        } else if hasLegacyMarkdown {
            kind = .legacyMarkdown
        } else if uppercaseExists {
            kind = .legacyUppercaseDocs
        } else {
            kind = .none
        }

        return ProjectDocsProfile(
            projectRootPath: projectRoot.path,
            docsDirectoryPath: docsURL.path,
            kind: kind,
            hasFollowupsHTML: hasFollowupsHTML,
            hasOpenQuestionsHTML: hasOpenQuestionsHTML,
            hasPlaytestHTML: hasPlaytestHTML,
            hasFunFactorHTML: hasFunFactorHTML,
            hasLegacyMarkdown: hasLegacyMarkdown
        )
    }
}
