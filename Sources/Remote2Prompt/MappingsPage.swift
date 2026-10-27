import Remote2PromptCore
import Remote2PromptMac
import SwiftUI

private struct ShortcutTarget: Identifiable {
    let button: RemoteButton
    let gesture: ButtonGesture
    var id: String { "\(button.rawValue):\(gesture.rawValue)" }
}

struct MappingsPage: View {
    @EnvironmentObject private var store: ConfigurationStore
    @EnvironmentObject private var runtime: RemoteMappingRuntime
    @ViewState private var selected: RemoteButton? = .select
    @ViewState private var capture: ShortcutTarget?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Toggle("启用自定义映射", isOn: Binding(get: { store.configuration.mappingsEnabled }, set: { value in store.update { $0.mappingsEnabled = value } }))
                    Spacer()
                    Button("补齐基本导航映射") { store.update { $0.fillBasicNavigationBindings() } }
                }
                Text(runtime.status).foregroundStyle(runtime.isRunning ? .green : .secondary)
                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 14) {
                        RemoteDiagram(selection: $selected, active: runtime.activeButtons, voiceHeld: runtime.voiceHeld)
                        Text("RC003 按键示意").font(.caption).foregroundStyle(.secondary)
                        if selected == nil { VoiceTriggerControls() }
                    }
                    .frame(width: 186)
                    VStack(spacing: 0) {
                        HStack {
                            Text("按键").frame(width: 54, alignment: .leading)
                            ForEach(ButtonGesture.allCases) { gesture in
                                Text(gesture.title).font(.headline).frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.vertical, 12)
                        ForEach(RemoteButton.allCases) { button in
                            Divider()
                            HStack(spacing: 10) {
                                Button { selected = button } label: {
                                    Text(button.title).frame(width: 54, alignment: .leading)
                                        .foregroundStyle(runtime.activeButtons.contains(button) ? .green : selected == button ? Color.accentColor : .primary)
                                }.buttonStyle(.plain)
                                ForEach(ButtonGesture.allCases) { gesture in actionCell(button, gesture) }
                            }
                            .padding(.vertical, 12)
                            .background(selected == button ? Color.accentColor.opacity(0.05) : .clear)
                        }
                        Divider()
                        HStack {
                            Button("语音键") { selected = nil }.buttonStyle(.plain)
                            Spacer()
                            Text("即时按下与释放 · \(store.configuration.voiceTrigger.title)")
                                .foregroundStyle(.secondary)
                        }.padding(.vertical, 14)
                    }
                    .padding(.horizontal, 12)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                }
                Text("三列分别设置单击、双击、长按。未设置双击或长按时，单击立即响应；补齐导航只填空项。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(24)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    LabeledContent("遥控器输入", value: inputTitle)
                    Divider().frame(height: 18)
                    LabeledContent("最近发送", value: outputTitle)
                }
                Text("只显示最近按键和发送请求，不保存输入文字；语音键按住时暂停其他映射。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).background(.bar)
        }
        .sheet(item: $capture) { target in
            ShortcutCaptureView(initial: store.configuration.invocation(for: target.button, gesture: target.gesture).shortcut) { result in
                switch result {
                case .cancelled: break
                case .cleared: store.update { $0.setAction(.none, for: target.button, gesture: target.gesture) }
                case .confirmed(let shortcut): store.update { $0.setShortcut(shortcut, for: target.button, gesture: target.gesture) }
                }
                capture = nil
            }
        }
    }

    private func actionCell(_ button: RemoteButton, _ gesture: ButtonGesture) -> some View {
        let invocation = store.configuration.invocation(for: button, gesture: gesture)
        return VStack(alignment: .leading, spacing: 5) {
            Picker("\(button.title)键\(gesture.title)", selection: Binding(
                get: { store.configuration.action(for: button, gesture: gesture) },
                set: { value in
                    if value == .customShortcut { capture = ShortcutTarget(button: button, gesture: gesture) }
                    else { store.update { $0.setAction(value, for: button, gesture: gesture) } }
                }
            )) {
                ForEach(MappedAction.allCases) { action in
                    Text(action == .customShortcut ? (invocation.shortcut?.displayTitle ?? action.title) : action.title).tag(action)
                }
            }
            .labelsHidden()
            .accessibilityLabel("\(button.title)键\(gesture.title)动作")
            if invocation.action == .customShortcut {
                Button("重新录入…") { capture = ShortcutTarget(button: button, gesture: gesture) }
                    .font(.caption).accessibilityLabel("重新录入\(button.title)键\(gesture.title)快捷键")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inputTitle: String {
        guard let activity = runtime.lastActivity else { return "等待遥控器按键" }
        return "\(activity.isVoice ? "语音键" : activity.button?.title ?? "未知") · \(activity.isDown ? "按下" : "松开")"
    }
    private var outputTitle: String {
        switch runtime.lastOutput {
        case .action(let invocation): invocation.resolvedShortcut?.displayTitle ?? invocation.action.title
        case .voice(let event): "\(event.trigger.title) · \(event.isDown ? "按下" : "松开")"
        case nil: "尚未发送"
        }
    }
}
