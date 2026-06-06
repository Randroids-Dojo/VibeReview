import XCTest
@testable import VibeReview

final class SpiralHTMLWriterTests: XCTestCase {
    func testCreatesMinimumDocsWhenMissing() throws {
        let root = try temporaryDirectory()
        let profile = ProjectDocsProfile(
            projectRootPath: root.path,
            docsDirectoryPath: root.appendingPathComponent("docs").path,
            kind: .none,
            hasFollowupsHTML: false,
            hasOpenQuestionsHTML: false,
            hasPlaytestHTML: false,
            hasFunFactorHTML: false,
            hasLegacyMarkdown: false
        )

        try SpiralHTMLWriter().ensureMinimumHTMLDocs(for: profile)

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("docs/PLAYTEST.html").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("docs/FOLLOWUPS.html").path))
    }

    func testNextIDUsesHighestExistingNumber() {
        let html = #"<section data-f="F-001"></section><section data-f="F-009"></section>"#

        let next = SpiralHTMLWriter().nextID(prefix: "F", in: html)

        XCTAssertEqual(next, "F-010")
    }

    func testRecordCaptureAppendsPlaytestAndFollowup() throws {
        let root = try temporaryDirectory()
        let docs = root.appendingPathComponent("docs", isDirectory: true)
        let artifactRoot = docs.appendingPathComponent("reviews/test-session", isDirectory: true)
        let profile = ProjectDocsProfile(
            projectRootPath: root.path,
            docsDirectoryPath: docs.path,
            kind: .none,
            hasFollowupsHTML: false,
            hasOpenQuestionsHTML: false,
            hasPlaytestHTML: false,
            hasFunFactorHTML: false,
            hasLegacyMarkdown: false
        )
        var session = ReviewSession(
            id: "test-session",
            title: "Test Game",
            projectRootPath: root.path,
            artifactRootPath: artifactRoot.path,
            docsProfile: profile,
            status: .active,
            createdAt: Date(),
            resumedAt: nil,
            endedAt: nil,
            captures: []
        )
        let capture = ReviewCapture(
            note: "The jump feels late",
            severity: .blocksRelease,
            rating: 2,
            tags: ["controls"],
            screenshotRelativePath: "captures/shot.png",
            browserSnapshotRelativePath: nil,
            browserURL: "http://localhost:3000",
            browserTitle: "Game",
            degradedReason: nil
        )
        session.captures = [capture]
        let writer = SpiralHTMLWriter()

        try writer.prepareSession(session)
        try writer.recordCapture(capture, in: session)

        let playtest = try String(contentsOf: docs.appendingPathComponent("PLAYTEST.html"))
        let followups = try String(contentsOf: docs.appendingPathComponent("FOLLOWUPS.html"))
        let report = try String(contentsOf: artifactRoot.appendingPathComponent("vibereview-session.html"))
        XCTAssertTrue(playtest.contains("data-vibereview-session=\"test-session\""))
        XCTAssertTrue(followups.contains("data-f=\"F-001\""))
        XCTAssertTrue(followups.contains("data-capture=\"\(capture.id.uuidString)\""))
        XCTAssertTrue(followups.contains("data-priority=\"blocks-release\""))
        XCTAssertTrue(report.contains("<h3>Tags:</h3>"))
        XCTAssertTrue(report.contains("<li>controls</li>"))
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
