import Foundation

Task { @MainActor in
    do {
        let command = try VibeReviewCommandLine.parse(Array(CommandLine.arguments.dropFirst()))
        try await VibeReviewCLIRunner().run(command)
        exit(0)
    } catch {
        fputs("vibereview: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

dispatchMain()

@MainActor
private struct VibeReviewCLIRunner {
    private let snapshotWaitNanoseconds: UInt64 = 2_500_000_000

    func run(_ command: VibeReviewCLICommand) async throws {
        switch command {
        case .start(let projectPath, let title):
            let store = SessionStore()
            let session = try activateSession(in: store, projectPath: projectPath, title: title)
            print("Started review `\(session.title)`")
            print("Session: \(session.id)")
            print("Artifacts: \(session.artifactRootPath)")

        case .capture(let projectPath, let noteSource, let severity, let rating, let tags):
            let note = try readNote(noteSource)
            let browserSnapshot = try await receiveBrowserSnapshot()
            let store = SessionStore()
            let session = try activateSession(in: store, projectPath: projectPath, title: nil)
            let pending = try store.createPendingCapture(browserSnapshot: browserSnapshot)
            try store.savePendingCapture(
                pending,
                note: note,
                severity: severity,
                rating: rating,
                tags: tags
            )
            print("Captured review feedback")
            print("Session: \(session.id)")
            print("Capture: \(pending.id.uuidString)")
            print("Screenshot: \(pending.screenshotURL.path)")
            if let browserSnapshotRelativePath = pending.browserSnapshotRelativePath {
                let browserSnapshotURL = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
                    .appendingPathComponent(browserSnapshotRelativePath)
                print("Browser snapshot: \(browserSnapshotURL.path)")
            } else {
                print("Browser snapshot: unavailable")
            }

        case .end(let projectPath):
            let store = SessionStore()
            guard let session = try store.latestSession(projectSelectionURL: URL(fileURLWithPath: projectPath)) else {
                throw VibeReviewCLIError("No VibeReview session exists for `\(projectPath)`.")
            }
            if store.activeSession?.id != session.id {
                try store.resumeSession(session)
            }
            try store.endActiveSession()
            print("Ended review `\(session.title)`")
            print("Session: \(session.id)")

        case .status(let projectPath):
            let store = SessionStore()
            if let projectPath {
                guard let session = try store.latestSession(projectSelectionURL: URL(fileURLWithPath: projectPath)) else {
                    throw VibeReviewCLIError("No VibeReview session exists for `\(projectPath)`.")
                }
                printSession(session)
            } else if let active = store.sessions.first(where: { $0.status == .active }) {
                printSession(active)
            } else if let latest = store.sessions.first {
                printSession(latest)
            } else {
                print("No VibeReview sessions found.")
            }

        case .list:
            let store = SessionStore()
            if store.sessions.isEmpty {
                print("No VibeReview sessions found.")
            } else {
                for session in store.sessions {
                    print("\(session.id)\t\(session.status.rawValue)\t\(session.captures.count) captures\t\(session.projectRootPath)")
                }
            }

        case .version:
            print("VibeReview \(Self.versionString())")

        case .help:
            print(VibeReviewCommandLine.helpText)
        }
    }

    private func activateSession(in store: SessionStore, projectPath: String, title: String?) throws -> ReviewSession {
        let projectURL = URL(fileURLWithPath: projectPath).standardizedFileURL
        let session = try store.startSession(projectSelectionURL: projectURL, title: title)
        if store.activeSession?.id == session.id {
            return session
        }
        try store.resumeSession(session)
        guard let activeSession = store.activeSession else {
            throw VibeReviewCLIError("Unable to activate the review session for `\(projectPath)`.")
        }
        return activeSession
    }

    private func receiveBrowserSnapshot() async throws -> BrowserSnapshot? {
        let server = BrowserSnapshotServer()
        server.start()
        defer { server.stop() }

        let start = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - start < snapshotWaitNanoseconds {
            if let snapshot = server.lastSnapshot {
                return snapshot
            }
            if !server.isRunning, let error = server.lastError {
                throw VibeReviewCLIError("Browser snapshot receiver could not start: \(error). Close the running VibeReview app or retry when port 37717 is free.")
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if !server.isRunning, let error = server.lastError {
            throw VibeReviewCLIError("Browser snapshot receiver could not start: \(error). Close the running VibeReview app or retry when port 37717 is free.")
        }
        return server.lastSnapshot
    }

    private func readNote(_ source: NoteSource) throws -> String {
        let note: String
        switch source {
        case .value(let value):
            note = value
        case .file(let path):
            note = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        case .standardInput:
            note = String(data: FileHandle.standardInput.readDataToEndOfFile(), encoding: .utf8) ?? ""
        }

        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VibeReviewCLIError("Review note cannot be empty.")
        }
        return trimmed
    }

    private func printSession(_ session: ReviewSession) {
        print("Session: \(session.id)")
        print("Title: \(session.title)")
        print("Status: \(session.status.rawValue)")
        print("Project: \(session.projectRootPath)")
        print("Artifacts: \(session.artifactRootPath)")
        print("Captures: \(session.captures.count)")
    }

    private static func versionString() -> String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let buildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        return "\(shortVersion) (\(buildVersion))"
    }
}
