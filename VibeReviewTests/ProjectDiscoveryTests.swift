import XCTest
@testable import VibeReview

final class ProjectDiscoveryTests: XCTestCase {
    func testLocatesProjectRootFromSubfolder() throws {
        let root = try temporaryDirectory()
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let nested = root.appendingPathComponent("src/game", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let discovered = ProjectDiscovery.locateProjectRoot(from: nested)

        XCTAssertEqual(discovered.standardizedFileURL.path, root.standardizedFileURL.path)
    }

    func testDetectsFullSpiralHTML() throws {
        let root = try temporaryDirectory()
        let docs = root.appendingPathComponent("docs", isDirectory: true)
        try FileManager.default.createDirectory(at: docs.appendingPathComponent("gdd", isDirectory: true), withIntermediateDirectories: true)
        for file in ["FOLLOWUPS.html", "OPEN_QUESTIONS.html", "PLAYTEST.html", "FUN_FACTOR_AUDIT.html"] {
            try "<html></html>".write(to: docs.appendingPathComponent(file), atomically: true, encoding: .utf8)
        }

        let profile = ProjectDiscovery.detectDocs(for: root)

        XCTAssertEqual(profile.kind, .fullSpiralHTML)
        XCTAssertEqual(profile.docsDirectoryPath, docs.path)
    }

    func testMissingDocsDefaultsToLowercaseDocs() throws {
        let root = try temporaryDirectory()

        let profile = ProjectDiscovery.detectDocs(for: root)

        XCTAssertEqual(profile.kind, .none)
        XCTAssertEqual(URL(fileURLWithPath: profile.docsDirectoryPath).lastPathComponent, "docs")
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
