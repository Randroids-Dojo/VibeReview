import SwiftUI

struct SettingsView: View {
    @StateObject private var buildInstallService = BuildInstallService()

    var body: some View {
        BuildInstallPane(buildInstallService: buildInstallService)
            .frame(minWidth: 820, minHeight: 620)
    }
}
