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
    @ViewState private var selectionRequest = 0
    var openAudioSettings: () -> Void = {}

    var body: some View {
        HStack(alignment: .top, spacing: 22) {
            remotePanel
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        voiceCard.id("voice")
                        ordinaryHeader
                        VStack(spacing: 12) {
                            mappingGroup("方向导航", buttons: [.up, .down, .left, .right, .select])
                            mappingGroup("常用按键", buttons: [.back, .home, .menu, .tv])
                            mappingGroup("设备控制", buttons: [.volumeUp, .volumeDown, .power])
                        }
                        Text("点选动作即可保存。键盘图标可直接录入快捷键；未设置双击或长按时，单击立即响应。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 4)
                }
                .onAppear { proxy.scrollTo("voice", anchor: .top) }
                .onChange(of: selectionRequest) { _, _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if let button = selected { proxy.scrollTo(button, anchor: .center) }
                        else { proxy.scrollTo("voice", anchor: .top) }
                    }
                }
            }
        }
        .padding(22)
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom) { activityBar }
        .sheet(item: $capture) { target in
            ShortcutCaptureView(
                initial: store.configuration.invocation(for: target.button, gesture: target.gesture).shortcut,
                context: "\(target.button.title)键 · \(target.gesture.title)"
            ) { result in
                switch result {
                case .cancelled: break
                case .cleared: store.update { $0.setAction(.none, for: target.button, gesture: target.gesture) }
                case .confirmed(let shortcut): store.update { $0.setShortcut(shortcut, for: target.button, gesture: target.gesture) }
                }
                capture = nil
            }
        }
    }

    private var voiceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: runtime.voiceHeld ? "mic.fill" : "mic")
                    .font(.title2).foregroundStyle(runtime.voiceHeld ? .green : Color.accentColor)
                    .frame(width: 42, height: 42)
                    .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) {
                    Text("语音键").font(.headline)
                    Text(runtime.voiceHeld ? "正在按住" : "按住开始，松开结束")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("启用语音触发", isOn: Binding(
                    get: { store.configuration.voiceEnabled },
                    set: { value in store.update { $0.voiceEnabled = value } }
                ))
                .toggleStyle(.switch).controlSize(.small)
            }
            if store.configuration.voiceEnabled {
                voiceTriggerOptions
            } else {
                DisclosureGroup("配置语音触发键") { voiceTriggerOptions.padding(.top, 6) }
                    .font(.callout)
            }
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.accentColor.opacity(0.16)))
    }

    private var voiceTriggerOptions: some View {
        HStack(spacing: 12) {
            Text("发送按键").foregroundStyle(.secondary)
            Picker("语音触发键", selection: Binding(
                get: { store.configuration.voiceTrigger },
                set: { value in store.update { $0.voiceTrigger = value } }
            )) {
                ForEach(VoiceTrigger.allCases) { Text($0.title).tag($0) }
            }
            .labelsHidden().frame(width: 175)
            Text("在输入法中选择同一个键")
                .font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button(action: openAudioSettings) { Label("音频设置", systemImage: "waveform") }
                .buttonStyle(.link)
        }
    }

    private var ordinaryHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("普通按键").font(.headline)
                Toggle("启用自定义映射", isOn: Binding(
                    get: { store.configuration.mappingsEnabled },
                    set: { value in store.update { $0.mappingsEnabled = value } }
                ))
                .toggleStyle(.switch).controlSize(.small)
            }
            Spacer()
            Button("填入常用动作") { store.update { $0.fillBasicNavigationBindings() } }
                .help("补齐常用动作的空位：12 项单击、1 项双击、7 项长按，保留已有设置")

        }
        .padding(.horizontal, 2)
    }

    private var remotePanel: some View {
        GeometryReader { geometry in
            let scale = min(0.82, max(0.5, (geometry.size.height - 50) / 690))
            VStack(spacing: 14) {
                RemoteDiagram(selection: $selected, active: runtime.activeButtons, voiceHeld: runtime.voiceHeld,
                              onSelection: { selectionRequest += 1 })
                    .scaleEffect(scale).frame(width: 186 * scale, height: 690 * scale)
                Text("RC003 · 点按按键定位设置")
                    .font(.caption).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
        .frame(width: 156)
    }

    private func mappingGroup(_ title: String, buttons: [RemoteButton]) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(title).font(.subheadline.weight(.semibold)).frame(width: 96, alignment: .leading)
                ForEach(ButtonGesture.allCases) { gesture in
                    Text(gesture.title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }.padding(.horizontal, 12).padding(.vertical, 10)
            Divider().padding(.horizontal, 12)
            VStack(spacing: 4) {
                ForEach(buttons) { button in
                    HStack(spacing: 10) {
                        Label(button.title, systemImage: button.symbol)
                            .font(.callout)
                            .labelStyle(MappingKeyLabelStyle(active: runtime.activeButtons.contains(button)))
                            .frame(width: 96, alignment: .leading)
                        ForEach(ButtonGesture.allCases) { gesture in
                            MappingActionCell(
                                button: button, gesture: gesture,
                                invocation: store.configuration.invocation(for: button, gesture: gesture),
                                choose: { action in store.update { $0.setAction(action, for: button, gesture: gesture) } },
                                record: { capture = ShortcutTarget(button: button, gesture: gesture) }
                            )
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 3)
                    .background(selected == button ? Color.accentColor.opacity(0.045) : .clear)
                    .id(button)
                }
            }.padding(.vertical, 7)
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.06)))
    }

    private var activityBar: some View {
        HStack(spacing: 18) {
            Label(InterfaceInspection.enabled ? "界面预览，未访问设备" : runtime.status, systemImage: runtime.isRunning ? "circle.fill" : "circle")
                .foregroundStyle(runtime.isRunning ? .green : .secondary)
                .lineLimit(1).help(runtime.status)
            Spacer(minLength: 0)
            Text("输入").foregroundStyle(.tertiary)
            Text(inputTitle).lineLimit(1)
            Divider().frame(height: 14)
            Text("输出").foregroundStyle(.tertiary)
            Text(outputTitle).lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 24).padding(.vertical, 13)
        .frame(maxWidth: .infinity).background(.bar)
        .accessibilityElement(children: .contain)
    }

    private var inputTitle: String {
        guard let activity = runtime.lastActivity else { return "等待按键" }
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

private struct MappingKeyLabelStyle: LabelStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon.font(.system(size: 11, weight: .medium))
                .foregroundStyle(active ? .green : .secondary)
                .frame(width: 24, height: 24)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
            configuration.title
        }
    }
}
