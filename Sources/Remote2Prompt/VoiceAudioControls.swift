import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

struct VoiceAudioControls: View {
    @EnvironmentObject private var store: ConfigurationStore
    @ObservedObject var audio: RemoteAudioRuntime

    var body: some View {
        Picker("虚拟音频设备", selection: Binding(
            get: { store.configuration.selectedVirtualInputUID ?? "" },
            set: { value in store.update { $0.selectedVirtualInputUID = value.isEmpty ? nil : value } }
        )) {
            Text("不选择").tag("")
            ForEach(audio.devices) { device in Text(device.name).tag(device.uid) }
            if let uid = store.configuration.selectedVirtualInputUID, !audio.devices.contains(where: { $0.uid == uid }) {
                Text("已保存的设备当前不可用").tag(uid)
            }
        }
        LabeledContent("音频输出", value: audio.outputStatus)
        HStack {
            Button("刷新设备") { audio.refreshDevices() }
            Button(audio.testingTone ? "正在发送测试音…" : "向此设备发送测试音") { audio.playTestTone() }
                .disabled(!audio.canTestTone)
        }
        if audio.devices.isEmpty {
            Text("未找到可用的 MiRemoteV 2ch 或 BlackHole 2ch。安装相应驱动后刷新；应用不会自动安装驱动或重启音频服务。")
                .foregroundStyle(.secondary)
            Link("查看 BlackHole 官方安装说明", destination: URL(string: "https://github.com/ExistentialAudio/BlackHole#installation-instructions")!)
        }
        Toggle("接收遥控器语音音频", isOn: Binding(
            get: { store.configuration.remoteAudioEnabled },
            set: { value in store.update { $0.remoteAudioEnabled = value; if value { $0.voiceEnabled = true } } }
        ))
        Text("开启后同时启用语音触发，并连接遥控器的音频通道；需要蓝牙授权。请在目标输入法中选择上方同一回环设备作为麦克风。")
            .foregroundStyle(.secondary)
        LabeledContent("遥控器音频", value: audio.status)
        Button("重新连接音频") { audio.retry() }
        Text("仅向明确选择的回环设备输出，不切换系统默认输入或输出。测试音在内存中生成，语音开始时立即取消测试音。")
            .font(.caption).foregroundStyle(.secondary)
    }
}
