import XCTest
@testable import VibeReview

@MainActor
final class SessionStoreTests: XCTestCase {
    func testUpdateCaptureRewritesSessionArtifacts() throws {
        let store = try makeStore()
        let session = try makeSession(in: store)
        let capture = try addCapture(to: store, session: session, note: "old note", tags: ["ux"])

        try store.updateCapture(
            capture,
            in: store.activeSession!,
            note: "new menu note",
            severity: .polish,
            rating: 5,
            tags: ["menu", "state"]
        )

        let updated = try XCTUnwrap(store.activeSession?.captures.first)
        XCTAssertEqual(updated.note, "new menu note")
        XCTAssertEqual(updated.severity, .polish)
        XCTAssertEqual(updated.rating, 5)
        XCTAssertEqual(updated.tags, ["menu", "state"])

        let report = try String(contentsOf: URL(fileURLWithPath: store.activeSession!.artifactRootPath)
            .appendingPathComponent("vibereview-session.html"))
        XCTAssertTrue(report.contains("new menu note"))
        XCTAssertTrue(report.contains("<li>menu</li>"))
        XCTAssertFalse(report.contains("old note"))
    }

    func testDeleteCaptureRemovesFilesAndRewritesSessionArtifacts() throws {
        let store = try makeStore()
        let session = try makeSession(in: store)
        let capture = try addCapture(to: store, session: session, note: "delete me", tags: ["ux"])
        let artifactRoot = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
        let screenshotURL = artifactRoot.appendingPathComponent(capture.screenshotRelativePath)
        let browserURL = artifactRoot.appendingPathComponent(try XCTUnwrap(capture.browserSnapshotRelativePath))

        try store.deleteCapture(capture, from: session)

        XCTAssertEqual(store.activeSession?.captures, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: screenshotURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: browserURL.path))

        let report = try String(contentsOf: artifactRoot.appendingPathComponent("vibereview-session.html"))
        XCTAssertFalse(report.contains("delete me"))
    }

    func testLoadsPersistedSessionAsPausedOnNewStoreInstance() throws {
        let registryURL = try temporaryDirectory().appendingPathComponent("sessions.json")
        let firstStore = makeStore(registryURL: registryURL)
        let session = try makeSession(in: firstStore)

        let secondStore = makeStore(registryURL: registryURL)

        XCTAssertEqual(secondStore.sessions.map(\.id), [session.id])
        XCTAssertEqual(secondStore.sessions.first?.status, .paused)
        XCTAssertNil(secondStore.activeSession)
    }

    func testChoosingProjectWithExistingSessionDoesNotCreateDuplicateSession() throws {
        let root = try temporaryDirectory()
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let firstStore = try makeStore()
        let originalSession = try firstStore.startSession(projectSelectionURL: root, title: "Clankers")
        _ = try addCapture(to: firstStore, session: originalSession, note: "existing capture", tags: ["ux"])

        let secondStore = try makeStore()
        let loadedSession = try secondStore.startSession(projectSelectionURL: root)

        XCTAssertEqual(loadedSession.id, originalSession.id)
        XCTAssertEqual(secondStore.sessions.count, 1)
        XCTAssertEqual(secondStore.sessions.first?.captures.count, 1)
        XCTAssertEqual(loadedSession.status, .paused)
        XCTAssertNil(secondStore.activeSession)

        try secondStore.resumeSession(loadedSession)

        XCTAssertEqual(secondStore.activeSession?.id, originalSession.id)
        XCTAssertEqual(secondStore.activeSession?.captures.count, 1)
    }

    func testChoosingProjectWithEndedSessionShowsExistingSessionWithoutReactivating() throws {
        let root = try temporaryDirectory()
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        let firstStore = try makeStore()
        let originalSession = try firstStore.startSession(projectSelectionURL: root, title: "Clankers")
        try firstStore.endActiveSession()

        let secondStore = try makeStore()
        let loadedSession = try secondStore.startSession(projectSelectionURL: root)

        XCTAssertEqual(loadedSession.id, originalSession.id)
        XCTAssertEqual(loadedSession.status, .ended)
        XCTAssertNil(secondStore.activeSession)
    }

    private func makeSession(in store: SessionStore) throws -> ReviewSession {
        let root = try temporaryDirectory()
        try FileManager.default.createDirectory(at: root.appendingPathComponent(".git"), withIntermediateDirectories: true)
        return try store.startSession(projectSelectionURL: root, title: "Test Game")
    }

    private func makeStore(registryURL: URL? = nil) throws -> SessionStore {
        let url: URL
        if let registryURL {
            url = registryURL
        } else {
            url = try temporaryDirectory().appendingPathComponent("sessions.json")
        }
        return SessionStore(persistence: SessionPersistence(registryURL: url))
    }

    private func makeStore(registryURL: URL) -> SessionStore {
        SessionStore(persistence: SessionPersistence(registryURL: registryURL))
    }

    private func addCapture(
        to store: SessionStore,
        session: ReviewSession,
        note: String,
        tags: [String]
    ) throws -> ReviewCapture {
        let id = UUID()
        let artifactRoot = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
        let capturesURL = artifactRoot.appendingPathComponent("captures", isDirectory: true)
        try FileManager.default.createDirectory(at: capturesURL, withIntermediateDirectories: true)

        let screenshotRelativePath = "captures/\(id.uuidString).png"
        let screenshotURL = artifactRoot.appendingPathComponent(screenshotRelativePath)
        try Data([1, 2, 3]).write(to: screenshotURL)

        let browserRelativePath = "captures/\(id.uuidString).browser.json"
        let browserURL = artifactRoot.appendingPathComponent(browserRelativePath)
        try "{}".write(to: browserURL, atomically: true, encoding: .utf8)

        let snapshot = BrowserSnapshot(
            capturedAt: Date(),
            url: "https://example.test/game",
            title: "Example Game",
            viewport: nil,
            scroll: nil,
            selectedText: nil,
            focusedElement: nil,
            domSummary: nil,
            storage: nil,
            canvases: [],
            consoleMessages: []
        )
        let pending = PendingCapture(
            id: id,
            screenshotURL: screenshotURL,
            screenshotRelativePath: screenshotRelativePath,
            browserSnapshotRelativePath: browserRelativePath,
            browserSnapshot: snapshot
        )
        try store.savePendingCapture(
            pending,
            note: note,
            severity: .issue,
            rating: 3,
            tags: tags
        )
        return try XCTUnwrap(store.activeSession?.captures.first)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
