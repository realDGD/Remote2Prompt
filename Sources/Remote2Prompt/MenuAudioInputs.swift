import Remote2PromptMac
import SwiftUI

/// Observe the adapter owners directly; child publications do not propagate through the runtime.
struct MenuAudioInputs: View {
    @EnvironmentObject private var store: ConfigurationStore
    @ObservedObject var priority: AudioInputPriorityRuntime
    @ObservedObject var audio: RemoteAudioRuntime
    let setupActive: Bool

    var body: some View {
        Menu("系统输入：\(priority.state.observedInput ?? "暂无可用设备")") {
            Picker("声音输入设备", selection: Binding(
                get: { priority.state.defaultUID ?? "" },
                set: { priority.selectInput(uid: $0) }
            )) {
                if priority.state.inputs.isEmpty { Text("暂无可用设备").tag("") }
                ForEach(priority.state.inputs, id: \.policy.uid) { Text($0.name).tag($0.policy.uid) }
            }
            .disabled(!canSelectSystemInput)
            if audio.sessionActive || priority.state.ownsInput || priority.state.pending {
                Text("语音结束并恢复输入后可切换")
            } else if priority.state.selectingInput { Text("正在等待系统确认…") }
            if let error = priority.state.selectionError { Text(error) }
            Divider()
            Button("刷新输入设备") { priority.refreshInputs() }
        }
        Menu("遥控器虚拟麦克风") {
            Picker("虚拟麦克风", selection: Binding(
                get: { store.configuration.selectedVirtualInputUID ?? "" },
                set: { value in store.update { $0.selectedVirtualInputUID = value.isEmpty ? nil : value } }
            )) {
                Text("未选择").tag("")
                ForEach(audio.devices) { Text($0.name).tag($0.uid) }
                if let uid = store.configuration.selectedVirtualInputUID, !audio.devices.contains(where: { $0.uid == uid }) {
                    Text("已保存的设备不可用").tag(uid)
                }
            }
            .disabled(store.persistenceError != nil || audio.sessionActive || setupActive)
            Text("此选项设置遥控器声音的输出目标")
        }
        Text(store.configuration.voiceEnabled ? "语音触发：\(store.configuration.voiceTrigger.title)" : "语音触发未启用")
    }

    private var canSelectSystemInput: Bool {
        priority.canSelectInput && !audio.sessionActive && !setupActive
    }
}
