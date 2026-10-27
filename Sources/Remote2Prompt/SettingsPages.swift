import AppKit
import ApplicationServices
import Remote2PromptCore
import SwiftUI

struct ConnectionPage: View {
    var body: some View {
        Form {
            Section {
                Label("尚未启用遥控器连接", systemImage: "appletvremote.gen4")
                    .font(.headline)
                Text("当前版本用于配置按键和语音偏好，尚不能接收遥控器按键或音频。")
                    .foregroundStyle(.secondary)
            } header: {
                Text("开发预览")
            }
            Section("计划支持") {
                LabeledContent("遥控器", value: "小米蓝牙遥控器 2 / 2 Pro")
                LabeledContent("使用方式", value: "按住说话，松开结束")
                LabeledContent("语音输入", value: "交给当前使用的输入法或听写工具")
            }
        }
        .formStyle(.grouped)
    }
}

struct MappingsPage: View {
    @EnvironmentObject private var store: ConfigurationStore
    @ViewState private var gesture: ButtonGesture = .click

    var body: some View {
        Form {
            Section {
                Toggle("启用自定义映射", isOn: preference(\.mappingsEnabled))
                Text("方案会保存在当前 Mac；遥控器连接功能可用后才能执行映射。语音键单独配置。")
                    .foregroundStyle(.secondary)
            }
            Section("按键动作") {
                Picker("操作方式", selection: $gesture) {
                    ForEach(ButtonGesture.allCases) { Text($0.title).tag($0) }
                }
                ForEach(RemoteButton.allCases) { button in
                    Picker(button.title, selection: action(for: button)) {
                        ForEach(MappedAction.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func preference(_ path: WritableKeyPath<AppConfiguration, Bool>) -> Binding<Bool> {
        Binding(get: { store.configuration[keyPath: path] }, set: { value in
            store.update { $0[keyPath: path] = value }
        })
    }

    private func action(for button: RemoteButton) -> Binding<MappedAction> {
        Binding(get: { store.configuration.action(for: button, gesture: gesture) }, set: { value in
            store.update { $0.setAction(value, for: button, gesture: gesture) }
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
                Text("此键将由遥控器语音会话发送给输入法。请在目标输入法设置相同的触发键；左右修饰键能否区分取决于目标应用。当前版本仅保存选项。")
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
    @ViewState private var accessibility = AXIsProcessTrusted()
    @ViewState private var inputMonitoring = CGPreflightListenEventAccess()

    var body: some View {
        Form {
            Section("系统权限") {
                LabeledContent("辅助功能", value: accessibility ? "已授权" : "未授权")
                LabeledContent("输入监控", value: inputMonitoring ? "已授权" : "未授权")
                LabeledContent("蓝牙", value: "尚未请求")
                Text("遥控器连接、按键监听和动作发送可用后，会在需要时引导授权。当前预览无需授权。")
                    .foregroundStyle(.secondary)
                Button("刷新权限状态") {
                    accessibility = AXIsProcessTrusted()
                    inputMonitoring = CGPreflightListenEventAccess()
                }
            }
            Section("隐私") {
                Text("当前版本仅在本机保存按键和语音偏好，不采集音频，也不联网。")
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
                LabeledContent("状态", value: "应用骨架 · 尚未支持硬件")
                LabeledContent("系统要求", value: "macOS 14 或更高版本")
            }
            Section("项目") {
                Text("面向 macOS，以 Swift 编写。开发和源码安装使用 Command Line Tools。")
            }
        }
        .formStyle(.grouped)
    }
}
