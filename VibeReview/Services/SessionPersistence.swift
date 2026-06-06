import Foundation

struct SessionPersistence {
    let registryURL: URL
    var fileManager: FileManager = .default

    init(registryURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.registryURL = registryURL ?? Self.defaultRegistryURL(fileManager: fileManager)
    }

    func loadRegistry() -> [ReviewSession] {
        guard fileManager.fileExists(atPath: registryURL.path),
              let data = try? Data(contentsOf: registryURL),
              let sessions = try? JSONCoding.decoder().decode([ReviewSession].self, from: data) else {
            return []
        }
        return refreshed(sessions)
    }

    func saveRegistry(_ sessions: [ReviewSession]) throws {
        try fileManager.createDirectory(at: registryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONCoding.encoder().encode(sessions)
        try data.write(to: registryURL, options: .atomic)
    }

    func loadProjectSessions(for profile: ProjectDocsProfile) -> [ReviewSession] {
        let reviewsURL = URL(fileURLWithPath: profile.docsDirectoryPath, isDirectory: true)
            .appendingPathComponent("reviews", isDirectory: true)
        guard let children = try? fileManager.contentsOfDirectory(
            at: reviewsURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let sessions = children.compactMap { child -> ReviewSession? in
            guard (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                return nil
            }
            return loadSession(at: child.appendingPathComponent("session.json"))
        }

        return sort(sessions)
    }

    func refreshed(_ sessions: [ReviewSession]) -> [ReviewSession] {
        let sessions = sessions.map { session in
            loadSession(at: URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
                .appendingPathComponent("session.json")) ?? session
        }
        return sort(sessions)
    }

    func sort(_ sessions: [ReviewSession]) -> [ReviewSession] {
        sessions.sorted {
            sortDate($0) > sortDate($1)
        }
    }

    private func loadSession(at url: URL) -> ReviewSession? {
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let session = try? JSONCoding.decoder().decode(ReviewSession.self, from: data) else {
            return nil
        }
        return session
    }

    private func sortDate(_ session: ReviewSession) -> Date {
        session.resumedAt ?? session.endedAt ?? session.createdAt
    }

    private static func defaultRegistryURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseURL
            .appendingPathComponent("VibeReview", isDirectory: true)
            .appendingPathComponent("sessions.json")
    }
}
