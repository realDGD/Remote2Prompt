import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

struct InputPriorityControls: View {
    @EnvironmentObject private var store: ConfigurationStore
    @ObservedObject var priority: AudioInputPriorityRuntime

    var body: some View {
        Toggle("按住语音键时使用遥控器输入", isOn: Binding(
            get: { store.configuration.preferVirtualInput },
            set: { value in store.update { $0.preferVirtualInput = value } }
        ))
        .toggleStyle(.switch).controlSize(.small)
        Text("平时跟随系统，不抢占麦克风。按下时切换到所选虚拟麦克风，松开并输出完尾音后，恢复按下前的输入。")
            .font(.callout).foregroundStyle(.secondary)
        if store.configuration.preferVirtualInput {
            LabeledContent("当前状态", value: phaseTitle)
            LabeledContent("系统正在使用", value: priority.state.observedInput ?? "尚未读取")
            LabeledContent("本次恢复到", value: priority.state.restoreInput ?? "按下语音键时记录")
            if priority.state.usingFallback {
                Label("按下前的设备已断开，将恢复到可用的实体麦克风。", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }
            if let error = priority.state.error { Text(error).font(.callout).foregroundStyle(.red) }
            DisclosureGroup("切换详情") {
                LabeledContent("最近请求", value: priority.state.requestedInput ?? "无")
                LabeledContent("最近确认", value: priority.state.confirmedInput ?? "无")
                Button("重试切换") { priority.retry() }
            }
            Text("需要开启语音触发、接收遥控器声音，并选择可用虚拟麦克风。只切换系统默认输入，不更改输出设备。")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var phaseTitle: String {
        switch priority.state.phase {
        case .disabled, .waiting: "等待语音键与音频就绪"
        case .unchanged: "语音输入已就绪"
        case .maintaining: "语音期间使用遥控器"
        case .requesting: "正在切换到遥控器"
        case .restoring: "正在恢复原输入"
        case .noFallback: "暂无可恢复的输入设备"
        case .failed: "切换尚未确认，正在重试"
        case .paused: "切换失败，已暂停重试"
        case .stopped: "输入切换已停止"
        }
    }
}
