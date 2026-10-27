import SwiftUI

private enum SettingsPage: String, CaseIterable, Identifiable {
    case connection, mappings, voice, permissions, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .connection: "连接"
        case .mappings: "按键映射"
        case .voice: "语音与音频"
        case .permissions: "权限"
        case .about: "关于"
        }
    }

    var symbol: String {
        switch self {
        case .connection: "antenna.radiowaves.left.and.right"
        case .mappings: "keyboard"
        case .voice: "waveform"
        case .permissions: "hand.raised"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @ViewState private var selection: SettingsPage? = .connection

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $selection) { page in
                Label(page.title, systemImage: page.symbol).tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 245)
            .safeAreaInset(edge: .bottom) {
                Text("Remote2Prompt · 开发预览")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        } detail: {
            VStack(spacing: 0) {
                if let error = store.persistenceError {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Group {
                    switch selection ?? .connection {
                    case .connection: ConnectionPage()
                    case .mappings: MappingsPage()
                    case .voice: VoicePage()
                    case .permissions: PermissionsPage()
                    case .about: AboutPage()
                    }
                }
                .disabled(store.persistenceError != nil)
            }
            .navigationTitle((selection ?? .connection).title)
        }
        .frame(minWidth: 780, minHeight: 560)
    }
}
