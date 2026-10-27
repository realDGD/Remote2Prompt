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
        Form {
            Section {
                Toggle("启用自定义映射", isOn: Binding(
                    get: { store.configuration.mappingsEnabled },
                    set: { value in store.update { $0.mappingsEnabled = value } }
                ))
                Text(runtime.status).foregroundStyle(runtime.isRunning ? .green : .secondary)
                Button("补齐基本导航映射") { store.update { $0.fillBasicNavigationBindings() } }
                Text("仅补齐空的单击动作，保留已有快捷键、双击和长按设置。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("选择遥控器按键") {
                HStack(alignment: .top, spacing: 24) {
                    VStack(spacing: 10) {
                        RemoteDiagram(selection: $selected, active: runtime.activeButtons, voiceHeld: runtime.voiceHeld)
                        Text("RC003 按键示意")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(width: 180)
                    VStack(alignment: .leading, spacing: 20) {
                        Text(selected.map { "\($0.title)键" } ?? "语音键")
                            .font(.title2.bold())
                        if let button = selected {
                            ForEach(ButtonGesture.allCases) { gesture in actionEditor(button, gesture) }
                            Text("没有设置双击或长按时，单击立即响应。方向、退格和音量动作可按住重复。")
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            VoiceTriggerControls()
                            Text("语音键独立即时处理，不参与普通键的单击、双击或长按。当前只发送触发键，不传输遥控器声音。")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Text("按住语音键时暂停其他映射，避免同时触发组合键。")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                }
                .padding(.vertical, 12)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $capture) { target in
            ShortcutCaptureView { shortcut in
                if let shortcut { store.update { $0.setShortcut(shortcut, for: target.button, gesture: target.gesture) } }
                capture = nil
            }
        }
    }

    private func actionEditor(_ button: RemoteButton, _ gesture: ButtonGesture) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(gesture.title, selection: Binding(
                get: { store.configuration.action(for: button, gesture: gesture) },
                set: { value in
                    if value == .customShortcut { capture = ShortcutTarget(button: button, gesture: gesture) }
                    else { store.update { $0.setAction(value, for: button, gesture: gesture) } }
                }
            )) {
                ForEach(MappedAction.allCases) { action in Text(action.title).tag(action) }
            }
            .accessibilityLabel("\(button.title)键\(gesture.title)动作")
            if let shortcut = store.configuration.invocation(for: button, gesture: gesture).shortcut {
                HStack {
                    Text(shortcut.displayTitle).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("重新录入…") { capture = ShortcutTarget(button: button, gesture: gesture) }
                        .accessibilityLabel("重新录入\(button.title)键\(gesture.title)快捷键")
                }
            }
        }
    }
}

private struct RemoteDiagram: View {
    @Binding var selection: RemoteButton?
    let active: Set<RemoteButton>
    let voiceHeld: Bool

    var body: some View {
        VStack(spacing: 16) {
            HStack { key(.power, "power"); Spacer() }
            key(nil, "mic.fill")
            VStack(spacing: 5) {
                key(.up, "chevron.up")
                HStack(spacing: 5) {
                    key(.left, "chevron.left")
                    key(.select, "circle.inset.filled")
                    key(.right, "chevron.right")
                }
                key(.down, "chevron.down")
            }
            HStack(spacing: 5) {
                key(.back, "arrow.uturn.backward")
                key(.home, "house")
                key(.menu, "line.3.horizontal")
            }
            HStack(spacing: 20) {
                key(.volumeDown, "minus")
                key(.volumeUp, "plus")
            }
            key(.tv, "tv")
        }
        .padding(18)
        .background(.background, in: RoundedRectangle(cornerRadius: 34))
        .overlay(RoundedRectangle(cornerRadius: 34).stroke(.quaternary))
    }

    private func key(_ button: RemoteButton?, _ symbol: String) -> some View {
        let pressed = button.map { active.contains($0) } ?? voiceHeld
        return Button { selection = button } label: {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .frame(width: 40, height: 36)
                .foregroundStyle(selection == button ? Color.accentColor : Color.primary)
                .background(pressed ? Color.green.opacity(0.25) : selection == button ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(selection == button ? Color.accentColor : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("选择\(button?.title ?? "语音")键")
        .accessibilityValue(pressed ? "按住中" : selection == button ? "已选择" : "")
        .help(button?.title ?? "语音键")
    }
}
