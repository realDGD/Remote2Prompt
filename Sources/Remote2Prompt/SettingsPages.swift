import AppKit
import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

struct ConnectionPage: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    var openMappings: () -> Void = {}

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
            Section("语音音频") {
                HStack {
                    LabeledContent("语音触发键", value: store.configuration.voiceEnabled ? store.configuration.voiceTrigger.title : "未启用")
                    Button("设置…", action: openMappings).buttonStyle(.link)
                }
                VoiceAudioControls(audio: runtime.audio)
            }
            Section("系统输入优先") {
                InputPriorityControls(priority: runtime.inputPriority)
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

struct PermissionsPage: View {
    var body: some View {
        Form {
            Section("按键所需权限") { PermissionControls() }
            Section("蓝牙与麦克风") {
                Text("按键由系统蓝牙配对。启用遥控器音频后才通过 CoreBluetooth 请求蓝牙访问；不读取 Mac 本机麦克风。")
                Button("打开蓝牙设置…") { openBluetoothSettings() }
            }
            Section("隐私") {
                Label("只处理兼容遥控器的按键", systemImage: "shield.lefthalf.filled")
                Text("快捷键录入仅接收当前窗口的按键，不读取其他应用输入。遥控器音频仅在启用后保留在内存，并写入你选择的回环设备；不录音存盘、不上传、不保存输入文字。")
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
            Button("打开输入监控设置…") {
                runtime.openInputMonitoringSettings()
                if !runtime.inputMonitoring { showDragGuide() }
            }
        }
        .onChange(of: runtime.manualInputHelpRequest) { _, _ in showDragGuide() }
        Text(runtime.inputMonitoring ? "系统已允许读取按键，可能来自设备控制授权。这个状态不代表已在输入监控列表中单独开启，无需重复申请。" : "设备控制授权也包含监听能力。需要单独申请时，按钮会直接发出系统请求；系统不再提示时，可打开输入监控设置检查。")
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

    private func showDragGuide() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { PermissionDragGuide.shared.show() }
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
