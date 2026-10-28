import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

private enum SetupStep: Int, CaseIterable {
    case preparation, configuration, check, finish
    var title: String {
        switch self {
        case .preparation: "准备遥控器"
        case .configuration: "选择要使用的功能"
        case .check: "试一下遥控器"
        case .finish: "确认配置"
        }
    }
    var shortTitle: String {
        switch self {
        case .preparation: "准备"
        case .configuration: "配置"
        case .check: "检查"
        case .finish: "完成"
        }
    }
}

struct SetupWizard: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    @Environment(\.dismiss) private var dismiss
    @ViewState private var step: SetupStep = .preparation
    @ViewState private var draft = AppConfiguration()
    @ViewState private var fillNavigation = false
    @ViewState private var skippedCheck = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ForEach(SetupStep.allCases, id: \.rawValue) { item in
                        if item != .preparation { Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }
                        Text(item.shortTitle)
                            .foregroundStyle(item == step ? .primary : .secondary)
                            .fontWeight(item == step ? .semibold : .regular)
                    }
                    Spacer()
                    Text("设置向导").foregroundStyle(.secondary)
                }.font(.callout)
                Text(step.title).font(.title2.bold())
            }.padding(24)
            Divider()
            Form { content }.formStyle(.grouped)
            Divider()
            HStack {
                Button("跳过配置") { dismiss() }.keyboardShortcut(.cancelAction)
                    .help("不保存本次选择，恢复原有配置")
                Spacer()
                if step == .configuration || step == .check {
                    Button("跳过检查") { skippedCheck = true; step = .finish }
                }
                if step != .preparation {
                    Button("上一步") { move(to: SetupStep(rawValue: step.rawValue - 1)!) }
                }
                Button(primaryTitle) { advance() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(step == .check && !checkPassed || store.persistenceError != nil)
            }.padding(20)
        }
        .frame(width: 720, height: 650)
        .onAppear {
            draft = store.configuration
            fillNavigation = draft.bindings.isEmpty
            runtime.beginSetup()
        }
        .onDisappear { runtime.endSetup() }
        .onChange(of: runtime.isRunning) { _, running in
            if running && step == .check && runtime.setupInput.stage == .idle { runtime.checkSetupButtons() }
        }
        .onChange(of: runtime.setupInput.buttonsComplete) { _, complete in
            if complete && step == .check && requiresVoice { runtime.checkSetupVoice() }
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .preparation:
            Section("连接") {
                Label(InterfaceInspection.enabled ? "界面预览，未连接设备" : runtime.status,
                      systemImage: runtime.isRunning ? "checkmark.circle" : "appletvremote.gen4")
                Text("先唤醒 RC003，再同时长按主页和菜单键进入配对，在 macOS 蓝牙设置中连接。")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("蓝牙设置…") { openBluetoothSettings() }.disabled(InterfaceInspection.enabled)
                    Button("重新检测") { runtime.retry() }.disabled(InterfaceInspection.enabled)
                }
                if let error = runtime.errorMessage { Text(error).foregroundStyle(.red) }
            }
            Section("按键权限") { PermissionControls() }
            Section {
                Text("手边没有遥控器也可以先配置，稍后再检查。向导内会暂停日常动作；“跳过配置”不保存任何更改。")
                    .foregroundStyle(.secondary)
            }
        case .configuration:
            Section("普通按键") {
                Toggle("启用自定义映射", isOn: $draft.mappingsEnabled)
                Toggle("补齐空的常用动作", isOn: $fillNavigation)
                Text("保留已有快捷键、双击和长按。之后可在按键映射页逐键调整。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("语音") {
                Toggle("启用语音触发", isOn: $draft.voiceEnabled)
                if draft.voiceEnabled {
                    triggerPicker
                } else {
                    DisclosureGroup("配置语音触发键") { triggerPicker }
                }
                SetupAudioOptions(audio: runtime.audio, draft: $draft)
                if draft.voiceEnabled || draft.remoteAudioEnabled {
                    Text(draft.remoteAudioEnabled ? "请在输入法中设置同一个触发键和虚拟麦克风。向导不读取 Mac 自带麦克风，也不安装驱动。" : "请在输入法中设置同一个触发键。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        case .check:
            Section("普通按键") {
                Label(runtime.setupInput.buttonsComplete ? "普通按键已检查" : "按下并松开两个不同按键", systemImage: runtime.setupInput.buttonsComplete ? "checkmark.circle.fill" : "hand.tap")
                    .foregroundStyle(runtime.setupInput.buttonsComplete ? .green : .primary)
                Text("例如方向上、确认。这里仅检测遥控器，不执行保存的动作。")
                    .foregroundStyle(.secondary)
                LabeledContent("已检测", value: "\(runtime.setupInput.buttons.count) / 2")
            }
            if requiresVoice {
                Section("语音键") {
                    Label(runtime.setupInput.complete ? "语音键已按下并松开" : runtime.setupInput.buttonsComplete ? "按住语音键，再松开" : "先完成上方普通按键检查",
                          systemImage: runtime.setupInput.complete ? "checkmark.circle.fill" : "mic")
                    Text("只检查物理按键；不传输声音，不验证输入法识别。")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                if !runtime.isRunning || !runtime.accessibility {
                    Text("尚未连接或按键权限未就绪。可以返回准备页处理，也可跳过检查后保存配置。")
                        .foregroundStyle(.secondary)
                }
                if !released { Text("请松开按键。") }
                Button("重新检查") { runtime.checkSetupButtons() }
                Text("跳过检查会明确记为未检查，可随时重跑向导。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .finish:
            Section("本次配置") {
                LabeledContent("自定义映射", value: draft.mappingsEnabled ? "开启" : "关闭")
                LabeledContent("语音触发", value: draft.voiceEnabled ? draft.voiceTrigger.title : "关闭")
                LabeledContent("虚拟麦克风", value: draft.remoteAudioEnabled ? "开启" : "关闭")
                if draft.remoteAudioEnabled {
                    LabeledContent("按住时切换系统输入", value: draft.preferVirtualInput ? "开启" : "关闭")
                }
                LabeledContent("常用动作", value: fillNavigation ? "补齐空项" : "保留现状")
            }
            Section("检查结果") {
                Label(skippedCheck ? "已跳过检查" : checkPassed ? "按键检查通过" : "尚未完成按键检查",
                      systemImage: !skippedCheck && checkPassed ? "checkmark.circle" : "circle.dashed")
                Text("保存配置不表示权限、遥控器音频或输入法已经可用。只有上述按键检查通过的项目才经过真实按下和松开验证。")
                    .foregroundStyle(.secondary)
                if draft.remoteAudioEnabled && draft.selectedVirtualInputUID == nil {
                    Text("尚未选择虚拟麦克风。返回上一步配置，或保存后到“连接与音频”选择。")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var triggerPicker: some View {
        Picker("发送按键", selection: $draft.voiceTrigger) {
            ForEach(VoiceTrigger.allCases) { Text($0.title).tag($0) }
        }
    }

    private var requiresVoice: Bool { draft.voiceEnabled || draft.remoteAudioEnabled }
    private var released: Bool { runtime.activeButtons.isEmpty && !runtime.voiceHeld }
    private var checkPassed: Bool {
        runtime.accessibility && runtime.isRunning && released && runtime.setupInput.buttonsComplete
            && (!requiresVoice || runtime.setupInput.complete)
    }
    private var primaryTitle: String {
        switch step {
        case .preparation: "继续配置"
        case .configuration: "开始检查"
        case .check: "继续"
        case .finish: "保存配置"
        }
    }
    private func move(to next: SetupStep) {
        if next == .check { skippedCheck = false; runtime.checkSetupButtons() }
        step = next
    }
    private func advance() {
        guard store.persistenceError == nil else { return }
        if step == .finish {
            var value = draft
            if fillNavigation { value.fillBasicNavigationBindings() }
            store.update { $0 = value }
            if store.persistenceError == nil { dismiss() }
        } else if step != .check || checkPassed, let next = SetupStep(rawValue: step.rawValue + 1) { move(to: next) }
    }
}

private struct SetupAudioOptions: View {
    @ObservedObject var audio: RemoteAudioRuntime
    @Binding var draft: AppConfiguration
    var body: some View {
        Toggle("启用虚拟麦克风", isOn: Binding(
            get: { draft.remoteAudioEnabled },
            set: { draft.remoteAudioEnabled = $0; if $0 { draft.voiceEnabled = true } }
        ))
        if draft.remoteAudioEnabled {
            Picker("虚拟麦克风", selection: Binding(
                get: { draft.selectedVirtualInputUID ?? "" },
                set: { draft.selectedVirtualInputUID = $0.isEmpty ? nil : $0 }
            )) {
                Text("稍后选择").tag("")
                ForEach(audio.devices) { Text($0.name).tag($0.uid) }
                if let uid = draft.selectedVirtualInputUID, !audio.devices.contains(where: { $0.uid == uid }) {
                    Text("已保存的设备不可用").tag(uid)
                }
            }
            Toggle("按住语音键时切换系统输入", isOn: $draft.preferVirtualInput)
            Text("默认跟随系统；开启后仅在按住时切到所选虚拟麦克风，松开排空后恢复。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
