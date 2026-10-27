import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

private enum SetupStep: Int, CaseIterable {
    case welcome, permissions, connection, buttons, voice, finish

    var title: String {
        switch self {
        case .welcome: "设置遥控器按键"
        case .permissions: "允许读取和发送按键"
        case .connection: "连接遥控器"
        case .buttons: "检测普通按键"
        case .voice: "检测语音键"
        case .finish: "保存按键设置"
        }
    }
}

struct SetupWizard: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    @Environment(\.dismiss) private var dismiss
    @ViewState private var step: SetupStep = .welcome
    @ViewState private var voiceTrigger: VoiceTrigger = .function
    @ViewState private var enableMappings = true
    @ViewState private var fillNavigation = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Remote2Prompt 设置向导").font(.caption).foregroundStyle(.secondary)
                Text(step.title).font(.title.bold())
                ProgressView(value: Double(step.rawValue + 1), total: Double(SetupStep.allCases.count))
                    .accessibilityLabel("第 \(step.rawValue + 1) 步，共 \(SetupStep.allCases.count) 步")
            }
            .padding(24)
            Divider()
            Form { content }
                .formStyle(.grouped)
            Divider()
            HStack {
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                if step != .welcome {
                    Button("上一步") { move(to: SetupStep(rawValue: step.rawValue - 1)!) }
                }
                Button(step == .finish ? "完成按键设置" : "继续") { advance() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdvance)
            }
            .padding(20)
        }
        .frame(width: 680, height: 590)
        .onAppear {
            voiceTrigger = store.configuration.voiceTrigger
            runtime.beginSetup()
        }
        .onDisappear { runtime.endSetup() }
        .onChange(of: runtime.isRunning) { _, running in
            if running && step == .buttons && runtime.setupInput.stage == .idle { runtime.checkSetupButtons() }
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome:
            Section {
                Label("用真实遥控器完成按键检测", systemImage: "appletvremote.gen4")
                    .font(.headline)
                Text("向导将检查权限、连接、普通键及语音键的按下与松开。请将 RC003 放在手边，并退出其他遥控器映射软件。")
                Text("向导运行时，遥控器日常映射会暂停，仅检测按键；取消后恢复原有设置。已有映射不会被重置。")
                    .foregroundStyle(.secondary)
            }
            Section("本版本的语音能力") {
                Text("可以把语音键转换为 Fn、左或右 Control 等触发键，暂不支持遥控器音频输入。此向导只检测按键，不验证语音识别结果。")
            }
        case .permissions:
            Section { PermissionControls() }
        case .connection:
            Section {
                Label(runtime.status, systemImage: runtime.isRunning ? "checkmark.circle.fill" : "link")
                    .foregroundStyle(runtime.isRunning ? .green : .primary)
                Text("先在 macOS 蓝牙设置中配对 RC003。发现设备后，应用还需要成功打开按键接口才能继续。")
                LabeledContent("已发现的遥控器接口", value: String(runtime.detectedCount))
                HStack {
                    Button("打开蓝牙设置…") { openBluetoothSettings() }
                    Button("重试连接") { runtime.retry() }
                }
                if let error = runtime.errorMessage { Text(error).foregroundStyle(.red) }
            }
        case .buttons:
            Section {
                Text("在同一只遥控器上，分别按下并松开两个不同的普通键，例如方向上和确认。")
                    .font(.headline)
                Text("这里不会执行已保存的动作。语音键不计入普通键检测。")
                    .foregroundStyle(.secondary)
                LabeledContent("已检测", value: "\(runtime.setupInput.buttons.count) / 2")
                ForEach(RemoteButton.allCases.filter { runtime.setupInput.buttons.contains($0) }) { button in
                    Label("\(button.title)键已按下并松开", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if !runtime.activeButtons.isEmpty { Text("请松开按键。") }
                Button("重新检测普通按键") { runtime.checkSetupButtons() }
                connectionProblem
            }
        case .voice:
            Section {
                Text("按住刚才那只遥控器的语音键，然后松开。")
                    .font(.headline)
                LabeledContent("按下", value: runtime.setupInput.voicePressed ? "已检测" : "等待按下")
                LabeledContent("松开", value: runtime.setupInput.voiceReleased ? "已检测" : "等待松开")
                Text("此步骤只检测物理按键，不会触发目标输入法或传输音频。")
                    .foregroundStyle(.secondary)
                if !runtime.setupInput.buttonsComplete {
                    Text("连接已变化，请先重新检测普通按键。")
                    Button("重新检测普通按键") { move(to: .buttons) }
                }
                connectionProblem
            }
            Section("日常使用的触发键") {
                Picker("语音触发键", selection: $voiceTrigger) {
                    ForEach(VoiceTrigger.allCases) { Text($0.title).tag($0) }
                }
                Text("完成时才保存。请在目标输入法中配置相同的键，并选择可用的麦克风。")
                    .foregroundStyle(.secondary)
            }
        case .finish:
            Section {
                Label(runtime.setupInput.complete ? "已检测到普通键和语音键的按下与松开" : "需要重新检测按键", systemImage: runtime.setupInput.complete ? "checkmark.circle" : "exclamationmark.circle")
                LabeledContent("语音触发键", value: voiceTrigger.title)
                Toggle("完成后启用自定义映射", isOn: $enableMappings)
                Toggle("补齐空的基本导航单击动作", isOn: $fillNavigation)
                Text("保留已有快捷键、双击和长按。取消不会保存本次选择。")
                    .foregroundStyle(.secondary)
                if !runtime.setupInput.complete {
                    Button("重新检测普通按键") { move(to: .buttons) }
                }
                connectionProblem
            }
            Section {
                Text("语音键检测不代表目标输入法已经启动。此版本不传输遥控器音频，日常使用前请在目标应用中核对触发键和麦克风。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var connectionProblem: some View {
        if !runtime.isRunning || !runtime.accessibility {
            Text(runtime.errorMessage ?? runtime.status).foregroundStyle(.red)
            Button("重试连接") { runtime.retry() }
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .welcome: true
        case .permissions: runtime.accessibility
        case .connection: runtime.accessibility && runtime.isRunning
        case .buttons: runtime.accessibility && runtime.isRunning && runtime.setupInput.buttonsComplete && released
        case .voice, .finish: runtime.accessibility && runtime.isRunning && runtime.setupInput.complete && released && store.persistenceError == nil
        }
    }

    private var released: Bool { runtime.activeButtons.isEmpty && !runtime.voiceHeld }

    private func move(to next: SetupStep) {
        if next == .buttons { runtime.checkSetupButtons() }
        if next == .voice { runtime.checkSetupVoice() }
        step = next
    }

    private func advance() {
        guard canAdvance else { return }
        if step == .finish {
            store.update {
                $0.voiceTrigger = voiceTrigger
                $0.mappingsEnabled = enableMappings
                if fillNavigation { $0.fillBasicNavigationBindings() }
            }
            if store.persistenceError == nil { dismiss() }
        } else if let next = SetupStep(rawValue: step.rawValue + 1) { move(to: next) }
    }
}
