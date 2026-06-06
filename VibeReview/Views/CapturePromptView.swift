import AppKit
import SwiftUI

struct CapturePromptView: View {
    let pending: PendingCapture
    @ObservedObject var sessionStore: SessionStore
    let onDone: () -> Void

    @State private var note = ""
    @State private var severity: CaptureSeverity = .issue
    @State private var rating = 3
    @State private var tags = ""
    @FocusState private var focusedField: FocusedField?

    private var tagSuggestions: [String] {
        TagAutocomplete.suggestions(for: tags, knownTags: sessionStore.knownTags)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Capture Feedback")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    onDone()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
            }

            HStack(alignment: .top, spacing: 14) {
                Image(nsImage: NSImage(contentsOf: pending.screenshotURL) ?? NSImage())
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 120)
                    .clipped()
                    .background(Color.black.opacity(0.2))

                VStack(alignment: .leading, spacing: 10) {
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
            }

            TextEditor(text: $note)
                .font(.body)
                .frame(minHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.25))
                )

            if pending.browserSnapshot == nil {
                Label("No browser snapshot was available for this capture.", systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if let url = pending.browserSnapshot?.url {
                Label(url, systemImage: "safari")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    onDone()
                }
                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 520, height: 456)
        .background(.regularMaterial)
    }

    private func acceptFirstTagSuggestion() {
        guard let suggestion = tagSuggestions.first else { return }
        acceptTagSuggestion(suggestion)
    }

    private func acceptTagSuggestion(_ suggestion: String) {
        tags = TagAutocomplete.replacingCurrentToken(in: tags, with: suggestion)
        focusedField = .tags
    }

    private func save() {
        do {
            let parsedTags = tags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            try sessionStore.savePendingCapture(
                pending,
                note: note.trimmingCharacters(in: .whitespacesAndNewlines),
                severity: severity,
                rating: rating,
                tags: parsedTags
            )
            onDone()
        } catch {
            sessionStore.lastError = error.localizedDescription
        }
    }

    private enum FocusedField: Hashable {
        case tags
    }
}
