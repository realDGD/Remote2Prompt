import SwiftUI

private enum SettingsPage: String, CaseIterable, Identifiable {
    case mappings, connection, permissions, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .connection: "连接与音频"
        case .mappings: "按键映射"
        case .permissions: "权限与隐私"
        case .about: "关于"
        }
    }

    var symbol: String {
        switch self {
        case .connection: "antenna.radiowaves.left.and.right"
        case .mappings: "keyboard"
        case .permissions: "hand.raised"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: ConfigurationStore
    @ViewState private var selection: SettingsPage? = .mappings

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $selection) { page in
                NavigationLink(value: page) {
                    Label(page.title, systemImage: page.symbol)
                }
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    ConfigurationTransferControls()
                    Button { store.isSetupPresented = true } label: {
                        Label("运行设置向导…", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.plain)
                    .disabled(store.persistenceError != nil)
                    Text(InterfaceInspection.interactive ? "Remote2Prompt · 界面预览" : "Remote2Prompt")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 245)
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
                    switch selection ?? .mappings {
                    case .connection: ConnectionPage(openMappings: { selection = .mappings })
                    case .mappings: MappingsPage(openAudioSettings: { selection = .connection })
                    case .permissions: PermissionsPage()
                    case .about: AboutPage()
                    }
                }
                .disabled(store.persistenceError != nil)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle((selection ?? .mappings).title)
            .toolbarBackground(.hidden, for: .windowToolbar)
        }
        .sheet(isPresented: $store.isSetupPresented) { SetupWizard() }
        .frame(minWidth: 1040, minHeight: 640)
    }
}
