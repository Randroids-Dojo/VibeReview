import SwiftUI

struct BuildInstallPane: View {
    @ObservedObject var buildInstallService: BuildInstallService
    @State private var outputExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                section("Source") {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledContent("Local clone") {
                            Text(buildInstallService.repositoryDisplayPath)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                        }

                        HStack(spacing: 8) {
                            Button("Choose...") { buildInstallService.chooseRepository() }
                                .disabled(buildInstallService.isRunning)
                            Button("Reset to Default") { buildInstallService.resetRepositoryToDefault() }
                                .disabled(buildInstallService.isRunning)
                        }
                    }
                }

                section("Versions") {
                    VStack(alignment: .leading, spacing: 14) {
                        versionRow(label: "Running", value: buildInstallService.runningVersion?.displayString)
                        Divider().opacity(0.45)
                        versionRow(label: "Repository", value: buildInstallService.repositoryVersion?.displayString)
                        Divider().opacity(0.45)
                        versionRow(label: "Installed", value: buildInstallService.installedVersion?.displayString)
                    }
                }

                section("Build") {
                    VStack(alignment: .leading, spacing: 14) {
                        Button {
                            buildInstallService.buildLatestAndReinstall()
                        } label: {
                            HStack(spacing: 12) {
                                if buildInstallService.isRunning {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "hammer.fill")
                                }
                                Text(buildInstallService.isRunning ? "Building & Installing..." : "Build Latest & Re-install")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(buildInstallService.isRunning || !buildInstallService.hasValidRepository)

                        if let message = buildInstallService.statusMessage {
                            statusLine(message)
                        } else if let idleStatus {
                            Label(idleStatus.message, systemImage: idleStatus.icon)
                                .font(.callout)
                                .foregroundStyle(idleStatus.color)
                        }

                        if let snippet = buildInstallService.lastOutputSnippet {
                            DisclosureGroup(isExpanded: $outputExpanded) {
                                ScrollView {
                                    Text(snippet)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(8)
                                }
                                .frame(maxHeight: 200)
                                .background(Color(nsColor: .textBackgroundColor).opacity(0.65))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            } label: {
                                Label("Diagnostic Output", systemImage: "text.alignleft")
                            }
                        }
                    }
                }

                Text("Builds the current local clone, installs VibeReview to /Applications, then quits and relaunches. Existing review data stays in the selected game project docs and Application Support. macOS may prompt for permission to update /Applications.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(28)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Build & Install")
                .font(.system(size: 28, weight: .semibold))
            Text("Rebuild VibeReview from your local repository and replace the copy in /Applications.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func versionRow(label: String, value: String?) -> some View {
        LabeledContent(label) {
            Text(value ?? "Unavailable")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(value == nil ? .secondary : .primary)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private func statusLine(_ message: String) -> some View {
        switch buildInstallService.state {
        case .idle:
            Label(message, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.callout)
        case .building, .installing:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .failed:
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .font(.callout)
        }
    }

    private var idleStatus: (message: String, icon: String, color: Color)? {
        guard buildInstallService.hasValidRepository else {
            return (
                "Choose the VibeReview repository root to enable build and re-install.",
                "exclamationmark.triangle.fill",
                .orange
            )
        }

        guard let repositoryVersion = buildInstallService.repositoryVersion else {
            return (
                "The selected repository does not expose a readable app version yet.",
                "info.circle.fill",
                .secondary
            )
        }

        let runningMatchesRepo = buildInstallService.runningVersion == repositoryVersion
        let installedMatchesRepo = buildInstallService.installedVersion == repositoryVersion

        switch (runningMatchesRepo, installedMatchesRepo) {
        case (true, true):
            return (
                "Ready to build from the selected local clone",
                "checkmark.circle.fill",
                .green
            )
        case (true, false):
            return (
                "The installed app is behind the selected repo. Build and re-install to sync /Applications.",
                "arrow.trianglehead.2.clockwise.rotate.90",
                .orange
            )
        case (false, true):
            return (
                "The running app differs from the selected repo. Rebuild if you want this repo installed and relaunched.",
                "info.circle.fill",
                .secondary
            )
        case (false, false):
            return (
                "Running and installed apps both differ from the selected repo. Build and re-install to sync them.",
                "arrow.trianglehead.2.clockwise.rotate.90",
                .orange
            )
        }
    }
}
