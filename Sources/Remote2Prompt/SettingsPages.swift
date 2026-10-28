import AppKit
import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

struct ConnectionPage: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    var openMappings: () -> Void = {}

    var body: some View {
        SettingsPageStack {
            SettingsCard("遥控器连接") {
                Label(InterfaceInspection.enabled ? "界面预览，未连接设备" : runtime.status, systemImage: runtime.isRunning ? "checkmark.circle.fill" : "appletvremote.gen4")
                    .foregroundStyle(runtime.isRunning ? .green : .primary)
                if let error = runtime.errorMessage { Text(error).foregroundStyle(.red) }
                HStack {
                    Button("蓝牙设置…") { openBluetoothSettings() }.disabled(InterfaceInspection.enabled)
                    Button("重试连接") { runtime.retry() }.disabled(InterfaceInspection.enabled)
                    Spacer()
                    Button("设置向导…") { store.isSetupPresented = true }
                }
                Text("先在系统蓝牙中配对 RC003。请退出其他遥控器映射软件，避免按键重复响应。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            SettingsCard("遥控器语音输入") {
                VoiceAudioControls(audio: runtime.audio)
                HStack {
                    LabeledContent("语音触发键", value: store.configuration.voiceEnabled ? store.configuration.voiceTrigger.title : "未启用")
                    Button("去设置", action: openMappings).buttonStyle(.link)
                }
            }
            SettingsCard("系统输入切换") {
                InputPriorityControls(priority: runtime.inputPriority)
            }
            SettingsCard {
                DisclosureGroup("连接诊断") {
                    LabeledContent("发现的遥控器接口", value: String(runtime.detectedCount))
                    LabeledContent("收到的按键报告", value: String(runtime.reportCount))
                    if let activity = runtime.lastActivity {
                        LabeledContent("最后按键", value: "\(activity.isVoice ? "语音键" : activity.button?.title ?? "未知") · \(activity.isDown ? "按下" : "松开")")
                    }
                }
            }
        }
    }
}

struct PermissionsPage: View {
    @EnvironmentObject private var runtime: RemoteMappingRuntime

    var body: some View {
        SettingsPageStack {
            SettingsCard("发送按键", compact: true) { DeviceControlPermissionRows() }
            SettingsCard("读取遥控器按键", compact: true) { InputMonitoringPermissionRows() }
            if let notice = runtime.permissionNotice {
                SettingsCard("授权提示") { Text(notice).font(.callout).foregroundStyle(.secondary) }
            }
            SettingsCard("蓝牙与声音") {
                Label("启用遥控器麦克风后才请求蓝牙访问", systemImage: "antenna.radiowaves.left.and.right")
                Text("应用不读取 Mac 自带麦克风。请在系统蓝牙中配对遥控器，声音写入你选择的虚拟麦克风。")
                    .font(.callout).foregroundStyle(.secondary)
                Button("蓝牙设置…") { openBluetoothSettings() }.disabled(InterfaceInspection.enabled)
            }
            SettingsCard("隐私保护") {
                Label("仅处理兼容遥控器的按键", systemImage: "appletvremote.gen4")
                Label("快捷键录入仅作用于当前窗口", systemImage: "keyboard")
                Label("语音只在内存处理，不录音、不上传", systemImage: "waveform")
                Text("设置和按键恢复记录仅保存在本机；不保存输入文字、完整 HID 报告或设备硬件地址。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            SettingsCard { PermissionTroubleshootingRows() }
        }
    }
}

private struct SettingsPageStack<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        Form { content }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String?
    let compact: Bool
    @ViewBuilder let content: Content
    init(_ title: String? = nil, compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title; self.compact = compact; self.content = content()
    }
    @ViewBuilder var body: some View {
        if let title { Section(title) { rows } }
        else { Section { rows } }
    }
    private var rows: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) { content }
            .padding(.vertical, compact ? 0 : 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The setup wizard reuses the same permission actions without introducing nested Forms.
struct PermissionControls: View {
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    var body: some View {
        DeviceControlPermissionRows()
        Divider()
        InputMonitoringPermissionRows()
        if let notice = runtime.permissionNotice { Text(notice).font(.callout).foregroundStyle(.secondary) }
        PermissionTroubleshootingRows()
    }
}

private struct PermissionStatusRow: View {
    let title: String
    let symbol: String
    let allowed: Bool
    let grantedTitle: String
    var body: some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Label(InterfaceInspection.enabled ? "未检查" : allowed ? grantedTitle : "未允许",
                  systemImage: InterfaceInspection.enabled ? "eye" : allowed ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(allowed && !InterfaceInspection.enabled ? .green : .secondary)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(allowed && !InterfaceInspection.enabled ? Color.green.opacity(0.09) : Color.primary.opacity(0.045), in: Capsule())
        }
    }
}

private struct DeviceControlPermissionRows: View {
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    var body: some View {
        PermissionStatusRow(title: IOHIDPermission.controlPermissionTitle, symbol: "hand.raised",
                            allowed: runtime.accessibility, grantedTitle: "已授权")
        Text("允许把映射后的遥控器按键发送给当前应用。")
            .font(.callout).foregroundStyle(.secondary)
        if runtime.accessibility {
            Button("管理权限…") { runtime.openAccessibilitySettings() }.disabled(InterfaceInspection.enabled)
        } else {
            HStack {
                Button("请求设备控制权限") { runtime.requestAccessibility() }
                    .disabled(runtime.requestingPermission || InterfaceInspection.enabled)
                Button("系统设置…") { runtime.openAccessibilitySettings() }.disabled(InterfaceInspection.enabled)
            }
        }
    }
}

private struct InputMonitoringPermissionRows: View {
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    var body: some View {
        PermissionStatusRow(title: "按键监听", symbol: "keyboard", allowed: runtime.inputMonitoring, grantedTitle: "系统已允许")
        Text(runtime.inputMonitoring ? "当前已具备按键读取能力，无需重复申请。" : "用于读取遥控器按键。先尝试系统授权；系统不再提示时，可打开设置手动添加。")
            .font(.callout).foregroundStyle(.secondary)
        HStack {
            if !runtime.inputMonitoring {
                Button("请求输入监控权限") { runtime.requestInputMonitoring() }
                    .disabled(runtime.requestingPermission || InterfaceInspection.enabled)
            }
            Button(runtime.inputMonitoring ? "管理输入监控…" : "系统设置与拖入引导…") {
                runtime.openInputMonitoringSettings()
                if !runtime.inputMonitoring { showDragGuide() }
            }.disabled(InterfaceInspection.enabled)
        }
        .onChange(of: runtime.manualInputHelpRequest) { _, _ in showDragGuide() }
    }
    private func showDragGuide() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { PermissionDragGuide.shared.show() }
    }
}

private struct PermissionTroubleshootingRows: View {
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    var body: some View {
        DisclosureGroup("授权后仍未生效？") {
            Text("设备控制授权也可能提供监听能力；“系统已允许”不表示在输入监控列表单独开启。较早系统的设备控制权限名为“辅助功能”。")
                .font(.callout).foregroundStyle(.secondary)
            Text("确认系统列表中添加的是当前应用。若没有该条目，可点击“＋”或把应用拖入列表。更新本地构建后，可能需要重新授权并重开。")
                .font(.callout).foregroundStyle(.secondary)
            Text(Bundle.main.bundleURL.path).font(.caption).textSelection(.enabled)
            HStack {
                Button("在 Finder 中显示应用") { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }.disabled(InterfaceInspection.enabled)
                Button("刷新权限状态") { runtime.refresh() }
            }
        }
    }
}

func openBluetoothSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.BluetoothSettings") {
        NSWorkspace.shared.open(url)
    }
}

struct AboutPage: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
    }

    var body: some View {
        Form {
            Section {
                Label("Remote2Prompt", systemImage: "mic.badge.plus")
                    .font(.title2.bold())
                Text("把遥控器变成 Mac 的语音与按键入口。")
                    .foregroundStyle(.secondary)
                LabeledContent("版本", value: version)
                LabeledContent("系统要求", value: "macOS 14 或更高版本")
                Text("提供按键映射、语音触发键与遥控器音频回环输出。需要在目标输入法中配置相同触发键及回环麦克风。")
                    .foregroundStyle(.secondary)
            }
            Section("项目") {
                Text("面向 macOS，以 Swift 编写。开发和源码安装使用 Command Line Tools。")
            }
        }
        .formStyle(.grouped)
    }
}
