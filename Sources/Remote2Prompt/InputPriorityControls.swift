import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

struct InputPriorityControls: View {
    @EnvironmentObject private var store: ConfigurationStore
    @ObservedObject var priority: AudioInputPriorityRuntime
    var body: some View {
        Toggle("遥控器在线时优先使用虚拟麦克风", isOn: Binding(
            get: { store.configuration.preferVirtualInput },
            set: { value in store.update { $0.preferVirtualInput = value } }
        ))
        Text("默认关闭。开启且遥控器音频就绪后，保持上方所选回环为系统默认输入；AirPods/USB 抢占时记住该实体输入，断连、关闭或正常退出时有条件恢复。不修改默认输出。")
            .foregroundStyle(.secondary)
        LabeledContent("输入优先", value: phaseTitle)
        LabeledContent("实际默认输入", value: priority.state.observedInput ?? "尚未读取")
        LabeledContent("最近请求", value: priority.state.requestedInput ?? "无")
        LabeledContent("最近确认", value: priority.state.confirmedInput ?? "无")
        LabeledContent("实体恢复目标", value: priority.state.restoreInput ?? "当前无可用实体输入")
        if let error = priority.state.error { Text(error).foregroundStyle(.red) }
        Button("重试输入优先") { priority.retry() }
        Text("需要启用语音触发、接收遥控器音频并选择可用回环设备。强制结束进程无法执行退出恢复；未知或聚合设备不会被用作实体回退。")
            .font(.caption).foregroundStyle(.secondary)
    }
    private var phaseTitle: String {
        switch priority.state.phase {
        case .disabled: "已关闭"
        case .waiting: "等待已就绪遥控器及可用回环设备"
        case .unchanged: "所选输入已生效，保留原有系统选择"
        case .maintaining: "保持虚拟输入"
        case .requesting: "等待系统确认虚拟输入"
        case .restoring: "等待系统确认实体恢复"
        case .noFallback: "暂无可恢复实体输入，保持现状"
        case .failed: "切换未确认，准备有限重试"
        case .paused: "重试三次失败，已暂停"
        case .stopped: "输入协调已停止"
        }
    }
}
