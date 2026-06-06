import Foundation

enum SpiralHTMLWriterError: Error {
    case invalidLedger(String)
}

struct SpiralHTMLWriter {
    var fileManager: FileManager = .default

    func prepareSession(_ session: ReviewSession) throws {
        let artifactRoot = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
        try fileManager.createDirectory(
            at: artifactRoot.appendingPathComponent("captures", isDirectory: true),
            withIntermediateDirectories: true
        )
        try ensureMinimumHTMLDocs(for: session.docsProfile)
        try writeSessionIndex(session)
        try writeSessionHTML(session)
    }

    func recordCapture(_ capture: ReviewCapture, in session: ReviewSession) throws {
        try writeSessionIndex(session)
        try writeSessionHTML(session)

        guard session.docsProfile.canMutateHTMLLedgers else { return }
        try ensureMinimumHTMLDocs(for: session.docsProfile)
        try appendCaptureToPlaytest(capture, session: session)
        if capture.severity.followupPriority != nil {
            try appendFollowup(for: capture, session: session)
        }
    }

    func ensureMinimumHTMLDocs(for profile: ProjectDocsProfile) throws {
        guard profile.canMutateHTMLLedgers else { return }
        let docsURL = URL(fileURLWithPath: profile.docsDirectoryPath, isDirectory: true)
        try fileManager.createDirectory(at: docsURL, withIntermediateDirectories: true)

        let files: [(String, String)] = [
            ("PLAYTEST.html", Templates.playtest),
            ("FOLLOWUPS.html", Templates.followups),
            ("OPEN_QUESTIONS.html", Templates.openQuestions),
            ("FUN_FACTOR_AUDIT.html", Templates.funFactor)
        ]

        for (name, template) in files {
            let url = docsURL.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: url.path) {
                try template.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    func nextID(prefix: String, in html: String) -> String {
        let pattern = "\(prefix)-([0-9]{3,})"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return "\(prefix)-001"
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let maxNumber = regex.matches(in: html, range: range).compactMap { match -> Int? in
            guard let numberRange = Range(match.range(at: 1), in: html) else { return nil }
            return Int(html[numberRange])
        }.max() ?? 0
        return "\(prefix)-\(String(format: "%03d", maxNumber + 1))"
    }

    private func writeSessionIndex(_ session: ReviewSession) throws {
        let url = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
            .appendingPathComponent("session.json")
        let data = try JSONCoding.encoder().encode(session)
        try data.write(to: url, options: .atomic)
    }

    private func writeSessionHTML(_ session: ReviewSession) throws {
        let html = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <title>VibeReview Session \(HTML.escape(session.title))</title>
        </head>
        <body>
        <header data-session="\(HTML.attribute(session.id))" data-status="\(session.status.rawValue)">
          <h1>VibeReview Session: \(HTML.escape(session.title))</h1>
          <dl>
            <dt>Project</dt><dd><code>\(HTML.escape(session.projectRootPath))</code></dd>
            <dt>Created</dt><dd><time datetime="\(DateFormats.htmlDateTime(session.createdAt))">\(DateFormats.htmlDateTime(session.createdAt))</time></dd>
            <dt>Status</dt><dd>\(HTML.escape(session.status.rawValue))</dd>
          </dl>
        </header>
        <main id="captures">
        \(session.captures.map(captureArticle).joined(separator: "\n\n"))
        </main>
        </body>
        </html>
        """
        let url = URL(fileURLWithPath: session.artifactRootPath, isDirectory: true)
            .appendingPathComponent("vibereview-session.html")
        try html.write(to: url, atomically: true, encoding: .utf8)
    }

    private func captureArticle(_ capture: ReviewCapture) -> String {
        let tags = capture.tags.isEmpty ? "" : """
            <section aria-label="Tags">
              <h3>Tags:</h3>
              <ul>\(capture.tags.map { "<li>\(HTML.escape($0))</li>" }.joined())</ul>
            </section>
        """
        let degraded = capture.degradedReason.map {
            "<dt>Degraded</dt><dd>\(HTML.escape($0))</dd>"
        } ?? ""
        let browserLink = capture.browserSnapshotRelativePath.map {
            "<dt>Browser snapshot</dt><dd><a href=\"\(HTML.attribute($0))\">\(HTML.escape($0))</a></dd>"
        } ?? ""
        return """
          <article data-capture="\(capture.id.uuidString)" data-severity="\(capture.severity.rawValue)">
            <h2>\(HTML.escape(capture.severity.title)): \(HTML.escape(capture.browserTitle ?? "Capture"))</h2>
            <figure>
              <img src="\(HTML.attribute(capture.screenshotRelativePath))" alt="Captured game screenshot">
              <figcaption>\(HTML.escape(capture.browserURL ?? "No browser URL captured"))</figcaption>
            </figure>
            <dl>
              <dt>Time</dt><dd><time datetime="\(DateFormats.htmlDateTime(capture.createdAt))">\(DateFormats.htmlDateTime(capture.createdAt))</time></dd>
              <dt>Rating</dt><dd>\(capture.rating)</dd>
              <dt>Note</dt><dd>\(HTML.escape(capture.note))</dd>
              \(browserLink)
              \(degraded)
            </dl>
            \(tags)
          </article>
        """
    }

    private func appendCaptureToPlaytest(_ capture: ReviewCapture, session: ReviewSession) throws {
        let playtestURL = docsURL(session, "PLAYTEST.html")
        var html = try String(contentsOf: playtestURL, encoding: .utf8)
        let entry = """

        <article data-vibereview-session="\(HTML.attribute(session.id))" data-capture="\(capture.id.uuidString)" data-severity="\(capture.severity.rawValue)">
          <h3>VibeReview capture: \(HTML.escape(capture.browserTitle ?? capture.severity.title))</h3>
          <dl>
            <dt>Session</dt><dd><a href="reviews/\(HTML.attribute(session.id))/vibereview-session.html">\(HTML.escape(session.title))</a></dd>
            <dt>Screenshot</dt><dd><a href="reviews/\(HTML.attribute(session.id))/\(HTML.attribute(capture.screenshotRelativePath))">\(HTML.escape(capture.screenshotRelativePath))</a></dd>
            <dt>URL</dt><dd>\(HTML.escape(capture.browserURL ?? "not captured"))</dd>
            <dt>Rating</dt><dd>\(capture.rating)</dd>
            <dt>Feedback</dt><dd>\(HTML.escape(capture.note))</dd>
          </dl>
        </article>
        """
        html = append(entry, beforeClosing: "body", in: html)
        try html.write(to: playtestURL, atomically: true, encoding: .utf8)
    }

    private func appendFollowup(for capture: ReviewCapture, session: ReviewSession) throws {
        guard let priority = capture.severity.followupPriority else { return }
        let followupsURL = docsURL(session, "FOLLOWUPS.html")
        var html = try String(contentsOf: followupsURL, encoding: .utf8)
        let id = nextID(prefix: "F", in: html)
        let title = capture.note.split(separator: "\n").first.map(String.init) ?? "Review feedback"
        let entry = """

        <section data-f="\(id)" data-priority="\(priority)">
          <h3>\(id): \(HTML.escape(title))</h3>
          <dl>
            <dt>Context</dt><dd>Captured during VibeReview session <a href="reviews/\(HTML.attribute(session.id))/vibereview-session.html">\(HTML.escape(session.title))</a>. Screenshot: <a href="reviews/\(HTML.attribute(session.id))/\(HTML.attribute(capture.screenshotRelativePath))">\(HTML.escape(capture.screenshotRelativePath))</a>. URL: \(HTML.escape(capture.browserURL ?? "not captured")).</dd>
            <dt>Feedback</dt><dd>\(HTML.escape(capture.note))</dd>
            <dt>Blocker (if any)</dt><dd>none recorded.</dd>
            <dt>Unblock condition</dt><dd>ready for review.</dd>
            <dt>PR / Dot reference</dt><dd>not started</dd>
          </dl>
        </section>
        """
        html = append(entry, beforeClosing: "main", in: html)
        try html.write(to: followupsURL, atomically: true, encoding: .utf8)
    }

    private func docsURL(_ session: ReviewSession, _ file: String) -> URL {
        URL(fileURLWithPath: session.docsProfile.docsDirectoryPath, isDirectory: true)
            .appendingPathComponent(file)
    }

    private func append(_ entry: String, beforeClosing tag: String, in html: String) -> String {
        let closing = "</\(tag)>"
        guard let range = html.range(of: closing, options: [.backwards, .caseInsensitive]) else {
            return html + entry
        }
        var updated = html
        updated.insert(contentsOf: entry + "\n", at: range.lowerBound)
        return updated
    }
}

private enum Templates {
    static let playtest = """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Release Playtest Checklist</title></head>
    <body>
    <header>
      <h1>Release Playtest Checklist</h1>
      <aside data-role="gate"><strong>The second gate.</strong> VibeReview appends captured playtest evidence here.</aside>
    </header>
    <section id="vibereview-captures"><h2>VibeReview Captures</h2></section>
    </body>
    </html>
    """

    static let followups = """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Followups</title></head>
    <body>
    <header>
      <h1>Followups</h1>
      <aside data-role="convention">Every followup must carry a <code>data-priority</code> attribute.</aside>
    </header>
    <main>
    <section id="blocks-release"><h2>Blocks Release</h2></section>
    <section id="nice-to-have"><h2>Nice To Have</h2></section>
    <section id="polish"><h2>Polish</h2></section>
    </main>
    </body>
    </html>
    """

    static let openQuestions = """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Open Questions</title></head>
    <body>
    <header>
      <h1>Open Questions</h1>
      <aside data-role="convention">Every question includes a recommended default.</aside>
    </header>
    <main id="open"><h2>Open</h2></main>
    </body>
    </html>
    """

    static let funFactor = """
    <!DOCTYPE html>
    <html lang="en">
    <head><meta charset="utf-8"><title>Fun Factor Audit</title></head>
    <body>
    <header><h1>Fun Factor Audit</h1></header>
    <main><p>Use VibeReview captures as qualitative evidence for fun-factor gaps.</p></main>
    </body>
    </html>
    """
}
