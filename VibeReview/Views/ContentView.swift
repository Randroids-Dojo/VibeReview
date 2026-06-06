import AppKit
import KeyboardShortcuts
import SwiftUI

struct ContentView: View {
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var browserServer: BrowserSnapshotServer
    let onOverlayHUDVisibilityChanged: (Bool) -> Void
    @StateObject private var buildInstallService = BuildInstallService()
    @State private var selectedSessionID: String?
    @State private var overlayHUDVisible: Bool
    private let buildInstallSelectionID = "__vibereview_build_install__"

    init(
        sessionStore: SessionStore,
        browserServer: BrowserSnapshotServer,
        overlayHUDVisible: Bool,
        onOverlayHUDVisibilityChanged: @escaping (Bool) -> Void
    ) {
        self.sessionStore = sessionStore
        self.browserServer = browserServer
        self.onOverlayHUDVisibilityChanged = onOverlayHUDVisibilityChanged
        self._overlayHUDVisible = State(initialValue: overlayHUDVisible)
    }

    private var selectedSession: ReviewSession? {
        if selectedSessionID == buildInstallSelectionID {
            return nil
        }
        if let selectedSessionID {
            return sessionStore.sessions.first(where: { $0.id == selectedSessionID })
        }
        return sessionStore.activeSession ?? sessionStore.sessions.first
    }

    private var isBuildInstallSelected: Bool {
        selectedSessionID == buildInstallSelectionID
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                header
                Divider()
                sessionList
            }
            .frame(minWidth: 280)
        } detail: {
            VStack(spacing: 0) {
                setupStrip
                Divider()
                if isBuildInstallSelected {
                    BuildInstallPane(buildInstallService: buildInstallService)
                } else if let selectedSession {
                    SessionDetailView(session: selectedSession, sessionStore: sessionStore)
                } else {
                    EmptySessionView(startAction: chooseProjectAndStart)
                }
            }
        }
        .frame(minWidth: 960, minHeight: 620)
        .alert("VibeReview Error", isPresented: Binding(
            get: { sessionStore.lastError != nil },
            set: { if !$0 { sessionStore.lastError = nil } }
        )) {
            Button("OK") { sessionStore.lastError = nil }
        } message: {
            Text(sessionStore.lastError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("VibeReview")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    chooseProjectAndStart()
                } label: {
                    Label("Start", systemImage: "record.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            if let active = sessionStore.activeSession {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(active.title)
                        .lineLimit(1)
                    Button {
                        do {
                            try sessionStore.endActiveSession()
                        } catch {
                            sessionStore.lastError = error.localizedDescription
                        }
                    } label: {
                        Label("End Review", systemImage: "stop.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }

    private var sessionList: some View {
        List(selection: $selectedSessionID) {
            Section("Reviews") {
                ForEach(sessionStore.sessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.title)
                                .font(.headline)
                            Spacer()
                            Text(session.status.rawValue)
                                .font(.caption)
                                .foregroundStyle(statusColor(for: session.status))
                        }
                        Text(session.projectRootPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text("\(session.captures.count) captures")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(session.id)
                    .padding(.vertical, 4)
                }
            }

            Section("Maintenance") {
                Label("Build & Install", systemImage: "hammer")
                    .tag(buildInstallSelectionID)

                Button {
                    buildInstallService.refreshVersionInfo()
                    selectedSessionID = buildInstallSelectionID
                } label: {
                    Label("Refresh Versions", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusColor(for status: SessionStatus) -> Color {
        switch status {
        case .active:
            .green
        case .paused:
            .orange
        case .ended:
            .secondary
        }
    }

    private var setupStrip: some View {
        HStack(spacing: 16) {
            Label(browserServer.isRunning ? "Snapshot receiver running" : "Snapshot receiver stopped",
                  systemImage: browserServer.isRunning ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(browserServer.isRunning ? .green : .orange)
            Label(browserServer.lastSnapshot == nil ? "No extension snapshot yet" : "Extension connected",
                  systemImage: browserServer.lastSnapshot == nil ? "wifi.slash" : "wifi")
            KeyboardShortcuts.Recorder("Capture Shortcut", name: .captureMoment)
                .frame(width: 260)
            Toggle("HUD", isOn: Binding(
                get: { overlayHUDVisible },
                set: { isVisible in
                    overlayHUDVisible = isVisible
                    onOverlayHUDVisibilityChanged(isVisible)
                }
            ))
            .toggleStyle(.switch)
            Spacer()
            Button {
                openChromeExtensionFolder()
            } label: {
                Label("Extension", systemImage: "puzzlepiece.extension")
            }
            .buttonStyle(.bordered)
        }
        .font(.callout)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func chooseProjectAndStart() {
        let panel = NSOpenPanel()
        panel.title = "Choose the game project folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let session = try sessionStore.startSession(projectSelectionURL: url)
                selectedSessionID = session.id
            } catch {
                sessionStore.lastError = error.localizedDescription
            }
        }
    }

    private func openChromeExtensionFolder() {
        if let resourceURL = Bundle.main.resourceURL?.appendingPathComponent("ChromeExtension"),
           FileManager.default.fileExists(atPath: resourceURL.path) {
            NSWorkspace.shared.activateFileViewerSelecting([resourceURL])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: "ChromeExtension")])
        }
    }
}

private struct EmptySessionView: View {
    let startAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No review session selected")
                .font(.title2)
            Button {
                startAction()
            } label: {
                Label("Start Review", systemImage: "record.circle")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SessionDetailView: View {
    let session: ReviewSession
    @ObservedObject var sessionStore: SessionStore
    @State private var capturePendingDeletion: ReviewCapture?
    @State private var captureBeingEdited: ReviewCapture?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title)
                        .font(.largeTitle)
                        .fontWeight(.semibold)
                    Text(session.projectRootPath)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Label(session.docsProfile.kind.rawValue, systemImage: "doc.richtext")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: session.artifactRootPath)])
                    } label: {
                        Label("Artifacts", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    if session.status != .active {
                        Button {
                            do {
                                try sessionStore.resumeSession(session)
                            } catch {
                                sessionStore.lastError = error.localizedDescription
                            }
                        } label: {
                            Label("Resume", systemImage: "play.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            Divider()

            if session.docsProfile.kind == .legacyMarkdown || session.docsProfile.kind == .legacyUppercaseDocs {
                Label("Legacy docs detected. V1 writes review artifacts but does not mutate Markdown ledgers.",
                      systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Divider()
            }

            List(session.captures) { capture in
                CaptureArtifactRow(
                    capture: capture,
                    artifactRootPath: session.artifactRootPath,
                    onEdit: {
                        captureBeingEdited = capture
                    },
                    onDelete: {
                        capturePendingDeletion = capture
                    }
                )
            }
        }
        .alert("Delete Capture?", isPresented: Binding(
            get: { capturePendingDeletion != nil },
            set: { if !$0 { capturePendingDeletion = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let capturePendingDeletion else { return }
                deleteCapture(capturePendingDeletion)
            }
            Button("Cancel", role: .cancel) {
                capturePendingDeletion = nil
            }
        } message: {
            Text("This removes the capture from the session report and deletes its screenshot and browser JSON artifact files.")
        }
        .sheet(item: $captureBeingEdited) { capture in
            CaptureEditSheet(
                capture: capture,
                knownTags: sessionStore.knownTags,
                onCancel: {
                    captureBeingEdited = nil
                },
                onSave: { note, severity, rating, tags in
                    updateCapture(capture, note: note, severity: severity, rating: rating, tags: tags)
                }
            )
        }
    }

    private func deleteCapture(_ capture: ReviewCapture) {
        do {
            try sessionStore.deleteCapture(capture, from: session)
            capturePendingDeletion = nil
        } catch {
            sessionStore.lastError = error.localizedDescription
        }
    }

    private func updateCapture(
        _ capture: ReviewCapture,
        note: String,
        severity: CaptureSeverity,
        rating: Int,
        tags: [String]
    ) {
        do {
            try sessionStore.updateCapture(
                capture,
                in: session,
                note: note,
                severity: severity,
                rating: rating,
                tags: tags
            )
            captureBeingEdited = nil
        } catch {
            sessionStore.lastError = error.localizedDescription
        }
    }
}

private struct CaptureArtifactRow: View {
    let capture: ReviewCapture
    let artifactRootPath: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(nsImage: NSImage(contentsOf: screenshotURL) ?? NSImage())
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 180, height: 112)
                .clipped()
                .background(Color.black.opacity(0.2))

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(capture.severity.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Label("Rating \(capture.rating)", systemImage: "star")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(DateFormats.htmlDateTime(capture.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button {
                        NSWorkspace.shared.open(screenshotURL)
                    } label: {
                        Label("Screenshot", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    if let browserSnapshotURL {
                        Button {
                            NSWorkspace.shared.open(browserSnapshotURL)
                        } label: {
                            Label("Browser JSON", systemImage: "curlybraces")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Text(capture.note)
                    .textSelection(.enabled)

                metadata
            }
        }
        .padding(.vertical, 10)
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 7) {
            MetadataLine(label: "URL", value: capture.browserURL ?? "No browser URL")
            MetadataLine(label: "Browser title", value: capture.browserTitle ?? "No browser title")
            MetadataLine(label: "Screenshot", value: capture.screenshotRelativePath)
            if let browserSnapshotRelativePath = capture.browserSnapshotRelativePath {
                MetadataLine(label: "Browser snapshot", value: browserSnapshotRelativePath)
            } else {
                MetadataLine(label: "Browser snapshot", value: "Not captured")
            }
            if let degradedReason = capture.degradedReason {
                MetadataLine(label: "Degraded", value: degradedReason)
            }
            HStack(alignment: .top, spacing: 8) {
                Text("Tags:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(width: 112, alignment: .trailing)
                if capture.tags.isEmpty {
                    Text("None")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(capture.tags, id: \.self) { tag in
                            Label(tag, systemImage: "tag")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var screenshotURL: URL {
        URL(fileURLWithPath: artifactRootPath, isDirectory: true)
            .appendingPathComponent(capture.screenshotRelativePath)
    }

    private var browserSnapshotURL: URL? {
        capture.browserSnapshotRelativePath.map {
            URL(fileURLWithPath: artifactRootPath, isDirectory: true)
                .appendingPathComponent($0)
        }
    }
}

private struct CaptureEditSheet: View {
    let capture: ReviewCapture
    let knownTags: [String]
    let onCancel: () -> Void
    let onSave: (String, CaptureSeverity, Int, [String]) -> Void

    @State private var note: String
    @State private var severity: CaptureSeverity
    @State private var rating: Int
    @State private var tags: String
    @FocusState private var focusedField: FocusedField?

    init(
        capture: ReviewCapture,
        knownTags: [String],
        onCancel: @escaping () -> Void,
        onSave: @escaping (String, CaptureSeverity, Int, [String]) -> Void
    ) {
        self.capture = capture
        self.knownTags = knownTags
        self.onCancel = onCancel
        self.onSave = onSave
        self._note = State(initialValue: capture.note)
        self._severity = State(initialValue: capture.severity)
        self._rating = State(initialValue: capture.rating)
        self._tags = State(initialValue: capture.tags.joined(separator: ", "))
    }

    private var tagSuggestions: [String] {
        TagAutocomplete.suggestions(for: tags, knownTags: knownTags)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Edit Capture")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 14) {
                Picker("Severity", selection: $severity) {
                    ForEach(CaptureSeverity.allCases) { severity in
                        Text(severity.title).tag(severity)
                    }
                }
                Picker("Rating", selection: $rating) {
                    ForEach(1...5, id: \.self) { value in
                        Text("\(value)").tag(value)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                TextField("Tags, comma separated", text: $tags)
                    .focused($focusedField, equals: .tags)
                    .onSubmit {
                        acceptFirstTagSuggestion()
                    }
                if !tagSuggestions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(tagSuggestions, id: \.self) { suggestion in
                                Button {
                                    acceptTagSuggestion(suggestion)
                                } label: {
                                    Label(suggestion, systemImage: "tag")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }

            TextEditor(text: $note)
                .font(.body)
                .frame(minHeight: 170)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                )

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                Button {
                    onSave(
                        note.trimmingCharacters(in: .whitespacesAndNewlines),
                        severity,
                        rating,
                        parsedTags
                    )
                } label: {
                    Label("Save", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 560, height: 430)
    }

    private var parsedTags: [String] {
        tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func acceptFirstTagSuggestion() {
        guard let suggestion = tagSuggestions.first else { return }
        acceptTagSuggestion(suggestion)
    }

    private func acceptTagSuggestion(_ suggestion: String) {
        tags = TagAutocomplete.replacingCurrentToken(in: tags, with: suggestion)
        focusedField = .tags
    }

    private enum FocusedField: Hashable {
        case tags
    }
}

private struct MetadataLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(label):")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .trailing)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(in: proposal.width ?? 600, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = layout(in: bounds.width, subviews: subviews).positions
        for (index, position) in positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(in maxWidth: CGFloat, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX > 0, currentX + size.width > maxWidth {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            usedWidth = max(usedWidth, currentX)
        }

        return (positions, CGSize(width: min(usedWidth, maxWidth), height: currentY + lineHeight))
    }
}

struct OverlayView: View {
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var browserServer: BrowserSnapshotServer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: sessionStore.activeSession == nil ? "pause.circle" : "record.circle.fill")
                .foregroundStyle(sessionStore.activeSession == nil ? Color.secondary : Color.red)
            VStack(alignment: .leading, spacing: 2) {
                Text(sessionStore.activeSession?.title ?? "No active review")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text("Cmd+Shift+R capture")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: browserServer.lastSnapshot == nil ? "wifi.slash" : "wifi")
                .foregroundStyle(browserServer.lastSnapshot == nil ? .orange : .green)
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(4)
    }
}
