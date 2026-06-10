import AppKit
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [ReviewSession] = []
    @Published private(set) var activeSession: ReviewSession?
    @Published var lastError: String?

    var knownTags: [String] {
        let tags = sessions.flatMap { session in
            session.captures.flatMap(\.tags)
        }
        var seen = Set<String>()
        return tags
            .filter { tag in
                let key = tag.lowercased()
                if seen.contains(key) {
                    return false
                }
                seen.insert(key)
                return true
            }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private let writer: SpiralHTMLWriter
    private let screenshotCapture: any ScreenshotCapturing
    private let persistence: SessionPersistence
    private let fileManager: FileManager

    init(
        writer: SpiralHTMLWriter = SpiralHTMLWriter(),
        screenshotCapture: any ScreenshotCapturing = ScreenshotCapture(),
        persistence: SessionPersistence? = nil,
        fileManager: FileManager = .default
    ) {
        self.writer = writer
        self.screenshotCapture = screenshotCapture
        self.persistence = persistence ?? SessionPersistence(fileManager: fileManager)
        self.fileManager = fileManager
        self.sessions = self.persistence.loadRegistry().map(pausedIfStaleActive)
        self.activeSession = nil
        try? persist()
        rewriteSessionArtifacts(for: sessions)
    }

    @discardableResult
    func startSession(projectSelectionURL: URL, title: String? = nil) throws -> ReviewSession {
        let projectRoot = ProjectDiscovery.locateProjectRoot(from: projectSelectionURL, fileManager: fileManager)
        let docsProfile = ProjectDiscovery.detectDocs(for: projectRoot, fileManager: fileManager)
        try mergeProjectSessions(for: docsProfile)

        if let existingSession = latestSession(for: projectRoot) {
            if existingSession.status == .active {
                activeSession = existingSession
            }
            return existingSession
        }

        let sessionID = makeSessionID()
        let docsRoot = URL(fileURLWithPath: docsProfile.docsDirectoryPath, isDirectory: true)
        let artifactRoot = docsRoot
            .appendingPathComponent("reviews", isDirectory: true)
            .appendingPathComponent(sessionID, isDirectory: true)

        let session = ReviewSession(
            id: sessionID,
            title: title ?? projectRoot.lastPathComponent,
            projectRootPath: projectRoot.path,
            artifactRootPath: artifactRoot.path,
            docsProfile: docsProfile,
            status: .active,
            createdAt: Date(),
            resumedAt: nil,
            endedAt: nil,
            captures: []
        )
        try writer.prepareSession(session)
        sessions.insert(session, at: 0)
        activeSession = session
        try persist()
        return session
    }

    func latestSession(projectSelectionURL: URL) throws -> ReviewSession? {
        let projectRoot = ProjectDiscovery.locateProjectRoot(from: projectSelectionURL, fileManager: fileManager)
        let docsProfile = ProjectDiscovery.detectDocs(for: projectRoot, fileManager: fileManager)
        try mergeProjectSessions(for: docsProfile)
        return latestSession(for: projectRoot)
    }

    func resumeSession(_ session: ReviewSession) throws {
        var updated = session
        updated.status = .active
        updated.resumedAt = Date()
        updated.endedAt = nil
        try writer.prepareSession(updated)
        replace(updated)
        activeSession = updated
        try persist()
    }

    func endActiveSession() throws {
        guard var session = activeSession else { return }
        session.status = .ended
        session.endedAt = Date()
        try writer.prepareSession(session)
        replace(session)
        activeSession = nil
        try persist()
    }

    func createPendingCapture(browserSnapshot: BrowserSnapshot?) throws -> PendingCapture {
        guard let session = activeSession else {
            throw NSError(domain: "VibeReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active review session."])
        }
        let captureID = UUID()
        let capturesURL = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
            .appendingPathComponent("captures", isDirectory: true)
        try fileManager.createDirectory(at: capturesURL, withIntermediateDirectories: true)
        let screenshotRelativePath = "captures/\(captureID.uuidString).png"
        let screenshotURL = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
            .appendingPathComponent(screenshotRelativePath)
        try screenshotCapture.captureDisplayContainingMouse(to: screenshotURL)

        var browserRelativePath: String?
        if let browserSnapshot {
            browserRelativePath = "captures/\(captureID.uuidString).browser.json"
            let url = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
                .appendingPathComponent(browserRelativePath!)
            let encoder = JSONCoding.encoder()
            try encoder.encode(browserSnapshot).write(to: url, options: .atomic)
        }

        return PendingCapture(
            id: captureID,
            screenshotURL: screenshotURL,
            screenshotRelativePath: screenshotRelativePath,
            browserSnapshotRelativePath: browserRelativePath,
            browserSnapshot: browserSnapshot
        )
    }

    func savePendingCapture(
        _ pending: PendingCapture,
        note: String,
        severity: CaptureSeverity,
        rating: Int,
        tags: [String]
    ) throws {
        guard var session = activeSession else {
            throw NSError(domain: "VibeReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "No active review session."])
        }
        let capture = ReviewCapture(
            id: pending.id,
            note: note,
            severity: severity,
            rating: rating,
            tags: tags,
            screenshotRelativePath: pending.screenshotRelativePath,
            browserSnapshotRelativePath: pending.browserSnapshotRelativePath,
            browserURL: pending.browserSnapshot?.url,
            browserTitle: pending.browserSnapshot?.title,
            degradedReason: pending.browserSnapshot == nil ? "Chrome extension snapshot was not available." : nil
        )
        session.captures.append(capture)
        try writer.recordCapture(capture, in: session)
        replace(session)
        activeSession = session
        try persist()
    }

    func deleteCapture(_ capture: ReviewCapture, from session: ReviewSession) throws {
        guard var updatedSession = sessions.first(where: { $0.id == session.id }) else {
            throw NSError(domain: "VibeReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Review session was not found."])
        }
        guard updatedSession.captures.contains(where: { $0.id == capture.id }) else {
            throw NSError(domain: "VibeReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Capture was not found in this session."])
        }

        updatedSession.captures.removeAll { $0.id == capture.id }
        try writer.removeCaptureFromLedgers(capture, in: updatedSession)
        try removeArtifactIfPresent(capture.screenshotRelativePath, in: updatedSession)
        if let browserSnapshotRelativePath = capture.browserSnapshotRelativePath {
            try removeArtifactIfPresent(browserSnapshotRelativePath, in: updatedSession)
        }
        try writer.prepareSession(updatedSession)
        replace(updatedSession)
        if activeSession?.id == updatedSession.id {
            activeSession = updatedSession
        }
        try persist()
    }

    @discardableResult
    func deleteProjectData(for session: ReviewSession) throws -> Int {
        let projectSessions = sessions.filter { isSameProject($0, session) }
        guard !projectSessions.isEmpty else {
            throw NSError(domain: "VibeReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Review project was not found."])
        }

        for projectSession in projectSessions {
            for capture in projectSession.captures {
                try writer.removeCaptureFromLedgers(capture, in: projectSession)
            }
            try removeDirectoryIfPresent(URL(fileURLWithPath: projectSession.artifactRootPath, isDirectory: true))
        }

        for docsDirectoryPath in Set(projectSessions.map(\.docsProfile.docsDirectoryPath)) {
            try removeReviewsDirectoryIfEmpty(in: docsDirectoryPath)
        }

        sessions.removeAll { candidate in
            projectSessions.contains { $0.id == candidate.id }
        }
        if let activeSession, isSameProject(activeSession, session) {
            self.activeSession = nil
        }
        try persist()
        return projectSessions.count
    }

    func updateCapture(
        _ capture: ReviewCapture,
        in session: ReviewSession,
        note: String,
        severity: CaptureSeverity,
        rating: Int,
        tags: [String]
    ) throws {
        guard var updatedSession = sessions.first(where: { $0.id == session.id }) else {
            throw NSError(domain: "VibeReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Review session was not found."])
        }
        guard let index = updatedSession.captures.firstIndex(where: { $0.id == capture.id }) else {
            throw NSError(domain: "VibeReview", code: 1, userInfo: [NSLocalizedDescriptionKey: "Capture was not found in this session."])
        }

        updatedSession.captures[index].note = note
        updatedSession.captures[index].severity = severity
        updatedSession.captures[index].rating = rating
        updatedSession.captures[index].tags = tags
        try writer.prepareSession(updatedSession)
        replace(updatedSession)
        if activeSession?.id == updatedSession.id {
            activeSession = updatedSession
        }
        try persist()
    }

    func reloadPersistedSessions() {
        sessions = persistence.loadRegistry().map(pausedIfStaleActive)
        activeSession = nil
        try? persist()
        rewriteSessionArtifacts(for: sessions)
    }

    private func replace(_ session: ReviewSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.insert(session, at: 0)
        }
        sessions = persistence.sort(sessions)
    }

    private func mergeProjectSessions(for profile: ProjectDocsProfile) throws {
        let discovered = persistence.loadProjectSessions(for: profile)
        for session in discovered {
            replace(pausedIfStaleActive(session))
        }
        if activeSession == nil {
            activeSession = sessions.first(where: { $0.status == .active })
        } else if let activeSession, let refreshed = sessions.first(where: { $0.id == activeSession.id }) {
            self.activeSession = refreshed
        }
        try persist()
        rewriteSessionArtifacts(for: sessions)
    }

    private func latestSession(for projectRoot: URL) -> ReviewSession? {
        let projectPath = projectRoot.standardizedFileURL.path
        return sessions.first {
            URL(fileURLWithPath: $0.projectRootPath).standardizedFileURL.path == projectPath
        }
    }

    private func persist() throws {
        try persistence.saveRegistry(sessions)
    }

    private func pausedIfStaleActive(_ session: ReviewSession) -> ReviewSession {
        guard session.status == .active, activeSession?.id != session.id else {
            return session
        }
        var updated = session
        updated.status = .paused
        return updated
    }

    private func rewriteSessionArtifacts(for sessions: [ReviewSession]) {
        for session in sessions {
            try? writer.prepareSession(session)
        }
    }

    private func removeArtifactIfPresent(_ relativePath: String, in session: ReviewSession) throws {
        let url = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
            .appendingPathComponent(relativePath)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func removeDirectoryIfPresent(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { return }
        try fileManager.removeItem(at: url)
    }

    private func removeReviewsDirectoryIfEmpty(in docsDirectoryPath: String) throws {
        let reviewsURL = URL(fileURLWithPath: docsDirectoryPath, isDirectory: true)
            .appendingPathComponent("reviews", isDirectory: true)
        guard fileManager.fileExists(atPath: reviewsURL.path) else { return }
        let remainingChildren = try fileManager.contentsOfDirectory(
            at: reviewsURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        if remainingChildren.isEmpty {
            try fileManager.removeItem(at: reviewsURL)
        }
    }

    private func isSameProject(_ lhs: ReviewSession, _ rhs: ReviewSession) -> Bool {
        URL(fileURLWithPath: lhs.projectRootPath).standardizedFileURL.path
            == URL(fileURLWithPath: rhs.projectRootPath).standardizedFileURL.path
    }

    private func makeSessionID() -> String {
        "\(DateFormats.fileStamp.string(from: Date()))-\(UUID().uuidString.prefix(8))"
    }
}

struct PendingCapture: Identifiable {
    var id: UUID
    var screenshotURL: URL
    var screenshotRelativePath: String
    var browserSnapshotRelativePath: String?
    var browserSnapshot: BrowserSnapshot?
}
