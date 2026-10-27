import AppKit
import ApplicationServices
import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

struct ConnectionPage: View {
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    var body: some View {
        Form {
            Section {
                Label(runtime.status, systemImage: "appletvremote.gen4")
                    .font(.headline)
                LabeledContent("发现的键盘接口", value: String(runtime.detectedCount))
                LabeledContent("语音键", value: runtime.voiceHeld ? "按住中" : "已释放")
                LabeledContent("收到的按键报告", value: String(runtime.reportCount))
                if let activity = runtime.lastActivity {
                    LabeledContent("最后按键", value: "\(activity.isVoice ? "语音键" : activity.button?.title ?? "未知")：\(activity.isDown ? "按下" : "松开")")
                }
                if let error = runtime.errorMessage { Text(error).foregroundStyle(.red) }
                Button("重试连接 / 恢复原生按键") { runtime.retry() }
                Text("请先在系统蓝牙中配对遥控器，再在按键映射页启用。语音键可以发送输入法触发按键；音频采集尚未启用。")
                    .foregroundStyle(.secondary)
            } header: {
                Text("遥控器状态")
            }
            Section("兼容设备") {
                LabeledContent("遥控器", value: "小米蓝牙遥控器 2 / 2 Pro")
                LabeledContent("使用方式", value: "按住说话，松开结束")
                LabeledContent("语音音频", value: "留待后续版本接入")
            }
        }
        .formStyle(.grouped)
    }
}

struct MappingsPage: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    @ViewState private var gesture: ButtonGesture = .click
    @ViewState private var captureButton: RemoteButton?

    var body: some View {
        Form {
            Section {
                Toggle("启用自定义映射", isOn: preference(\.mappingsEnabled))
                Button("补齐基本导航映射") {
                    let defaults: [RemoteButton: MappedAction] = [.up: .arrowUp, .down: .arrowDown, .left: .arrowLeft, .right: .arrowRight, .select: .enter, .back: .backspace, .power: .escape, .volumeUp: .volumeUp, .volumeDown: .volumeDown]
                    store.update { configuration in
                        for (button, action) in defaults where configuration.action(for: button, gesture: .click) == .none {
                            configuration.setAction(action, for: button, gesture: .click)
                        }
                    }
                }
                Text("仅补齐空的单击映射，保留已配置的动作和其他手势。")
                    .font(.caption).foregroundStyle(.secondary)
                Text(runtime.status).foregroundStyle(runtime.isRunning ? .green : .secondary)
                Text("语音键即时发送，不参与双击或长按。说话按键按住时，其他映射暂停，避免触发修饰键组合。")
                    .foregroundStyle(.secondary)
            }
            Section("按键动作") {
                Picker("操作方式", selection: $gesture) {
                    ForEach(ButtonGesture.allCases) { Text($0.title).tag($0) }
                }
                ForEach(RemoteButton.allCases) { button in
                    Picker(selection: action(for: button)) {
                        ForEach(MappedAction.allCases) { action in
                            Text(action == .customShortcut ? (store.configuration.invocation(for: button, gesture: gesture).shortcut?.displayTitle ?? action.title) : action.title).tag(action)
                        }
                    } label: {
                        Label(button.title, systemImage: runtime.activeButtons.contains(button) ? "circle.fill" : "circle")
                    }
                    if store.configuration.action(for: button, gesture: gesture) == .customShortcut {
                        Button("重新录入\(button.title)快捷键") { captureButton = button }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $captureButton) { button in
            ShortcutCaptureView { shortcut in
                if let shortcut { store.update { $0.setShortcut(shortcut, for: button, gesture: gesture) } }
                captureButton = nil
            }
        }
    }

    private func preference(_ path: WritableKeyPath<AppConfiguration, Bool>) -> Binding<Bool> {
        Binding(get: { store.configuration[keyPath: path] }, set: { value in
            store.update { $0[keyPath: path] = value }
        })
    }

    private func action(for button: RemoteButton) -> Binding<MappedAction> {
        Binding(get: { store.configuration.action(for: button, gesture: gesture) }, set: { value in
            if value == .customShortcut { captureButton = button }
            else { store.update { $0.setAction(value, for: button, gesture: gesture) } }
        })
    }
}

struct VoicePage: View {
    @EnvironmentObject private var store: ConfigurationStore

    var body: some View {
        Form {
            Section {
                Picker("语音触发键", selection: Binding(
                    get: { store.configuration.voiceTrigger },
                    set: { value in store.update { $0.voiceTrigger = value } }
                )) {
                    ForEach(VoiceTrigger.allCases) { Text($0.title).tag($0) }
                }
                Text("启用按键映射后，按住语音键会即时按下所选触发键，松开即释放。请在输入法中配置相同触发键；当前版本尚不传输遥控器音频。")
                    .foregroundStyle(.secondary)
            } header: {
                Text("语音触发")
            }
            Section {
                Toggle("遥控器在线时优先使用虚拟麦克风", isOn: Binding(
                    get: { store.configuration.preferVirtualInput },
                    set: { value in store.update { $0.preferVirtualInput = value } }
                ))
                Text("默认关闭。启用后，计划在遥控器就绪期间保持所选虚拟输入；最后一只遥控器断开后恢复最近的实体麦克风。")
                    .foregroundStyle(.secondary)
                LabeledContent("音频链路", value: "尚未启用")
                Text("当前版本不会切换系统麦克风，也不安装音频驱动。")
                    .foregroundStyle(.secondary)
            } header: {
                Text("输入设备优先级")
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionsPage: View {
    @EnvironmentObject private var runtime: RemoteMappingRuntime

    var body: some View {
        Form {
            Section("系统权限") {
                LabeledContent(IOHIDPermission.controlPermissionTitle, value: runtime.accessibility ? "已授权" : "未授权")
                LabeledContent("输入监控", value: runtime.inputMonitoring ? "已单独授权" : "未单独授权")
                LabeledContent("蓝牙", value: "尚未请求")
                Text("按键映射需要设备控制授权。该权限也包含事件监听；如果系统仍拒绝打开遥控器，再单独授予输入监控。macOS 27 将原“辅助功能”改名为“设备控制和数据访问”。授权或本地构建更新后，请重开应用再核对。")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("请求输入监控权限") { runtime.requestInputMonitoring() }
                    Button("打开输入监控设置…") { runtime.openInputMonitoringSettings() }
                }
                HStack {
                    Button("请求\(IOHIDPermission.controlPermissionTitle)权限") { runtime.requestAccessibility() }
                    Button("打开对应设置…") { runtime.openAccessibilitySettings() }
                }
                if let notice = runtime.permissionNotice { Text(notice).foregroundStyle(.secondary) }
                Text("若系统没有再次弹出提示，请在打开的权限列表中启用 Remote2Prompt；列表中没有时，点击“＋”添加当前应用。")
                    .foregroundStyle(.secondary)
                Button("在 Finder 中显示当前应用") {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }
                Button("刷新权限状态") { runtime.refresh() }
            }
            Section("隐私") {
                Text("仅处理匹配遥控器的按键。快捷键录入仅在当前窗口内生效，不读取其他应用输入，不采集音频，也不联网。")
            }
        }
        .formStyle(.grouped)
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
                LabeledContent("状态", value: "按键映射开发预览 · 音频尚未接入")
                LabeledContent("系统要求", value: "macOS 14 或更高版本")
            }
            Section("项目") {
                Text("面向 macOS，以 Swift 编写。开发和源码安装使用 Command Line Tools。")
            }
        }
        .formStyle(.grouped)
    }
}
