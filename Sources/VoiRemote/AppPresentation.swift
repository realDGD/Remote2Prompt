import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppPresentation: ObservableObject {
    @Published var keepDockVisible: Bool {
        didSet {
            defaults.set(keepDockVisible, forKey: "appearance.keepDockVisible.v1")
            updateActivation()
        }
    }
    private let defaults: UserDefaults
    private var opener: (@MainActor () -> Void)?
    private var pendingOpen = false
    private var launchResolved = false
    private(set) var settingsVisible = false
    private weak var settingsWindow: NSWindow?
    private var observers: [NSObjectProtocol] = []

    init(defaults: UserDefaults) {
        self.defaults = defaults
        keepDockVisible = defaults.bool(forKey: "appearance.keepDockVisible.v1")
    }
    func installOpener(_ action: @escaping @MainActor () -> Void) {
        opener = action
        if pendingOpen { showSettings() }
    }
    func finishLaunch(silent: Bool) {
        guard !launchResolved else { return }
        launchResolved = true
        updateActivation()
        if !silent { showSettings() }
    }
    func showSettings() {
        guard let opener else { pendingOpen = true; return }
        pendingOpen = false
        settingsVisible = true
        updateActivation()
        opener()
        NSApp.activate(ignoringOtherApps: true)
    }
    func attach(_ window: NSWindow) {
        guard settingsWindow !== window else { return }
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        settingsWindow = window
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.settingsVisible = false
                self?.updateActivation()
            }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSWindow.didBecomeMainNotification, object: window, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.settingsVisible = true
                self?.updateActivation()
            }
        })
    }
    private func updateActivation() {
        NSApp.setActivationPolicy(settingsVisible || keepDockVisible ? .regular : .accessory)
    }
    func shutdown() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        opener = nil
    }
}

struct SettingsWindowAttachment: NSViewRepresentable {
    let presentation: AppPresentation
    func makeNSView(context: Context) -> AttachmentView { AttachmentView(presentation: presentation) }
    func updateNSView(_ view: AttachmentView, context: Context) {}
    final class AttachmentView: NSView {
        let presentation: AppPresentation
        init(presentation: AppPresentation) { self.presentation = presentation; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { presentation.attach(window) }
        }
    }
}

@MainActor
final class LoginItemSettings: ObservableObject {
    @Published private(set) var enabled = false
    @Published private(set) var recoveryPending = false
    @Published private(set) var detail = ""
    @Published private(set) var error: String?
    let inspection: Bool
    init(inspection: Bool) { self.inspection = inspection; refresh() }
    func refresh() {
        guard !inspection else { detail = "预览模式，不修改系统登录项。"; return }
        let status = SMAppService.mainApp.status
        recoveryPending = LoginItemMaintenance.isPending()
        enabled = status == .enabled || status == .requiresApproval
        switch status {
        case .enabled: detail = "登录后静默运行，只显示菜单栏图标。"
        case .requiresApproval: detail = "需要在系统登录项设置中允许 VoiRemote。"
        case .notRegistered:
            detail = recoveryPending
                ? "安装后未能恢复自动启动，可在此重新开启。" : "未启用自动启动。"
        case .notFound:
            detail = recoveryPending ? "安装后未能恢复自动启动，可在此重新开启。"
                : "系统尚未找到登录项。可尝试启用；若失败，请确认应用位于“应用程序”。"
        @unknown default: detail = "无法确认系统登录项状态。"
        }
    }
    func setEnabled(_ value: Bool) {
        guard !inspection else { return }
        error = nil
        do {
            if value {
                try SMAppService.mainApp.register()
                LoginItemMaintenance.cancelPending()
            } else {
                LoginItemMaintenance.cancelPending()
                if [.enabled, .requiresApproval].contains(SMAppService.mainApp.status) {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch { self.error = "无法更新登录项：\(error.localizedDescription)" }
        refresh()
    }
    func cancelRecovery() {
        guard !inspection else { return }
        LoginItemMaintenance.cancelPending()
        error = nil
        refresh()
    }
    func openSystemSettings() { if !inspection { SMAppService.openSystemSettingsLoginItems() } }
}

struct GeneralPage: View {
    @EnvironmentObject private var presentation: AppPresentation
    @EnvironmentObject private var login: LoginItemSettings
    var body: some View {
        Form {
            Section("启动") {
                Toggle("登录时自动启动", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                    .disabled(login.inspection)
                Text(login.detail).font(.callout).foregroundStyle(.secondary)
                if let error = login.error { Text(error).foregroundStyle(.red) }
                if login.recoveryPending && !login.enabled {
                    Button("保持关闭，不再恢复") { login.cancelRecovery() }
                }
                Button("打开系统登录项设置…") { login.openSystemSettings() }.disabled(login.inspection)
            }
            Section("Dock") {
                Toggle("关闭设置后仍在 Dock 显示", isOn: $presentation.keepDockVisible)
                Text("默认仅在设置窗口打开时显示 Dock 图标。关闭设置后，VoiRemote 会继续在菜单栏运行。")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .onAppear { login.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
    }
}
