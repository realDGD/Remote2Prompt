import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

struct VoiceAudioControls: View {
    @EnvironmentObject private var store: ConfigurationStore
    @ObservedObject var audio: RemoteAudioRuntime

    var body: some View {
        Toggle("启用虚拟麦克风", isOn: Binding(
            get: { store.configuration.remoteAudioEnabled },
            set: { value in store.update { $0.remoteAudioEnabled = value; if value { $0.voiceEnabled = true } } }
        ))
        .toggleStyle(.switch).controlSize(.small)
        Text("把遥控器麦克风的声音送入下方所选的虚拟麦克风，供输入法识别；同时启用语音触发。按住遥控器语音键说话，并在输入法中选择同一个虚拟麦克风。此开关不负责安装虚拟设备。")
            .font(.callout).foregroundStyle(.secondary)
        HStack {
            Picker("虚拟麦克风", selection: Binding(
                get: { store.configuration.selectedVirtualInputUID ?? "" },
                set: { value in store.update { $0.selectedVirtualInputUID = value.isEmpty ? nil : value } }
            )) {
                Text("请选择设备").tag("")
                ForEach(audio.devices) { device in Text(device.name).tag(device.uid) }
                if let uid = store.configuration.selectedVirtualInputUID, !audio.devices.contains(where: { $0.uid == uid }) {
                    Text("已保存的设备当前不可用").tag(uid)
                }
            }
            Button { audio.refreshDevices() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless).disabled(InterfaceInspection.enabled).help("刷新音频设备").accessibilityLabel("刷新音频设备")
        }
        if audio.devices.isEmpty {
            if InterfaceInspection.enabled {
                Text("界面预览不连接音频设备").font(.caption).foregroundStyle(.secondary)
            } else {
                Label("未找到 MiRemoteV 2ch 或 BlackHole 2ch", systemImage: "speaker.slash")
                    .font(.callout).foregroundStyle(.secondary)
                Link("查看虚拟麦克风安装说明", destination: URL(string: "https://github.com/ExistentialAudio/BlackHole#installation-instructions")!)
            }
        }
        if store.configuration.remoteAudioEnabled {
            LabeledContent("音频连接", value: audio.status)
            Button("重新连接音频") { audio.retry() }.disabled(InterfaceInspection.enabled)
        }
        DisclosureGroup("测试与设备状态") {
            LabeledContent("设备状态", value: audio.outputStatus)
            Button(audio.testingTone ? "正在发送测试音…" : "发送测试音到虚拟麦克风") { audio.playTestTone() }
                .disabled(!audio.canTestTone)
            Text("测试音只发往所选设备，开始语音时会自动停止。应用不安装音频驱动，也不重启系统音频服务。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
