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
    @ViewState private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SettingsPage.allCases, selection: $selection) { page in
                Label(page.title, systemImage: page.symbol).tag(page)
            }
            .listStyle(.sidebar)
            .toolbar(removing: .sidebarToggle)
            .navigationSplitViewColumnWidth(min: 170, ideal: 195, max: 245)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    Button { store.isSetupPresented = true } label: {
                        Label("运行设置向导…", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.plain)
                    .disabled(store.persistenceError != nil)
                    Text("Remote2Prompt")
                        .font(.caption).foregroundStyle(.secondary)
                }
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
                    switch selection ?? .mappings {
                    case .connection: ConnectionPage(openMappings: { selection = .mappings })
                    case .mappings: MappingsPage(openAudioSettings: { selection = .connection })
                    case .permissions: PermissionsPage()
                    case .about: AboutPage()
                    }
                }
                .disabled(store.persistenceError != nil)
            }
        }
        // Keep title and toggle owned by the window, rather than moving toolbar items between columns.
        .navigationTitle((selection ?? .mappings).title)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                    }
                } label: {
                    Label(columnVisibility == .detailOnly ? "显示边栏" : "隐藏边栏", systemImage: "sidebar.left")
                }
                .help(columnVisibility == .detailOnly ? "显示边栏" : "隐藏边栏")
            }
        }
        .sheet(isPresented: $store.isSetupPresented) { SetupWizard() }
        .frame(minWidth: 1040, minHeight: 640)
    }
}
