import AppKit
import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

struct ConnectionPage: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var runtime: RemoteMappingRuntime

    var body: some View {
        Form {
            Section("遥控器连接") {
                Label(runtime.status, systemImage: "appletvremote.gen4")
                    .font(.headline)
                LabeledContent("已发现的遥控器接口", value: String(runtime.detectedCount))
                if let error = runtime.errorMessage { Text(error).foregroundStyle(.red) }
                HStack {
                    Button("打开蓝牙设置…") { openBluetoothSettings() }
                    Button("重试连接") { runtime.retry() }
                }
                Text("先在系统蓝牙中配对 RC003，再启用按键映射。请退出其他遥控器映射软件，避免重复响应。")
                    .foregroundStyle(.secondary)
                Button("运行设置向导…") { store.isSetupPresented = true }
            }
            Section("语音键") {
                VoiceTriggerControls()
                LabeledContent("当前按键", value: runtime.voiceHeld ? "按住中" : "已松开")
            }
            Section("语音音频") {
                Label("暂不支持遥控器音频输入", systemImage: "waveform.slash")
                Text("当前可以将语音键转换为输入法触发键，但不会传输遥控器声音。请在目标输入法中选择其他可用的麦克风。")
                    .foregroundStyle(.secondary)
                Text("本版本不切换系统麦克风，也不安装音频驱动。")
                    .foregroundStyle(.secondary)
            }
            Section {
                DisclosureGroup("连接详情") {
                    LabeledContent("收到的按键报告", value: String(runtime.reportCount))
                    if let activity = runtime.lastActivity {
                        LabeledContent("最后按键", value: "\(activity.isVoice ? "语音键" : activity.button?.title ?? "未知")：\(activity.isDown ? "按下" : "松开")")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct VoiceTriggerControls: View {
    @EnvironmentObject private var store: ConfigurationStore

    var body: some View {
        Picker("语音触发键", selection: Binding(
            get: { store.configuration.voiceTrigger },
            set: { value in store.update { $0.voiceTrigger = value } }
        )) {
            ForEach(VoiceTrigger.allCases) { Text($0.title).tag($0) }
        }
        Text("按住语音键立即按下所选键，松开即释放。请在目标输入法中设置相同触发键；左右 Control 是各自独立的按键。")
            .foregroundStyle(.secondary)
    }
}

struct PermissionsPage: View {
    var body: some View {
        Form {
            Section("按键所需权限") { PermissionControls() }
            Section("蓝牙与麦克风") {
                Text("遥控器由系统蓝牙配对，当前按键功能不请求蓝牙或麦克风权限。")
                Button("打开蓝牙设置…") { openBluetoothSettings() }
            }
            Section("隐私") {
                Label("只处理兼容遥控器的按键", systemImage: "shield.lefthalf.filled")
                Text("快捷键录入仅接收当前窗口的按键，不读取其他应用输入。本版本不采集音频、不保存输入文字，也不联网。")
                Text("设置和原生按键恢复记录保存在本机；不记录完整 HID 报告或设备硬件地址。")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionControls: View {
    @EnvironmentObject private var runtime: RemoteMappingRuntime

    var body: some View {
        LabeledContent(IOHIDPermission.controlPermissionTitle, value: runtime.accessibility ? "已授权" : "未授权")
        HStack {
            Button("请求\(IOHIDPermission.controlPermissionTitle)权限") { runtime.requestAccessibility() }
                .disabled(runtime.requestingPermission)
            Button("打开对应设置…") { runtime.openAccessibilitySettings() }
        }
        Text("用于发送映射后的按键。macOS 27 将原“辅助功能”改名为“设备控制和数据访问”。")
            .foregroundStyle(.secondary)
        Divider()
        LabeledContent("按键监听", value: runtime.inputMonitoring ? "系统已允许" : "系统未允许")
        HStack {
            if !runtime.inputMonitoring {
                Button("请求输入监控权限") { runtime.requestInputMonitoring() }
                    .disabled(runtime.requestingPermission)
            }
            Button("打开输入监控设置…") { runtime.openInputMonitoringSettings() }
        }
        Text(runtime.inputMonitoring ? "系统已允许读取按键，可能来自设备控制授权。这个状态不代表已在输入监控列表中单独开启，无需重复申请。" : "设备控制授权也包含监听能力。需要单独申请时，按钮会直接发出系统请求并打开输入监控设置；macOS 不会为每次点击重复弹窗。")
            .foregroundStyle(.secondary)
        if let notice = runtime.permissionNotice {
            Text(notice).foregroundStyle(.secondary).accessibilityLabel("授权请求结果：\(notice)")
        }
        DisclosureGroup("授权后仍未生效？") {
            Text("请确认系统列表中的应用来自下方路径。若列表没有当前应用，可点击“＋”添加。本地构建更新后可能需要重新授权并重开应用。")
            Text(Bundle.main.bundleURL.path)
                .font(.caption).textSelection(.enabled)
            HStack {
                Button("在 Finder 中显示当前应用") {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }
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
                Text("当前支持按键映射和语音触发键；暂不支持遥控器音频输入。")
                    .foregroundStyle(.secondary)
            }
            Section("项目") {
                Text("面向 macOS，以 Swift 编写。开发和源码安装使用 Command Line Tools。")
            }
        }
        .formStyle(.grouped)
    }
}
