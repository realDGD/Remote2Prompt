import Remote2PromptCore
import SwiftUI

struct GestureAdvancedControls: View {
    @EnvironmentObject private var store: ConfigurationStore
    @Binding var selected: RemoteButton?
    var onSelection: () -> Void = {}
    @ViewState private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ScrollView {
                HStack(alignment: .top, spacing: 28) {
                    timingControls.frame(maxWidth: .infinity, alignment: .topLeading)
                    Divider()
                    behaviorControls.frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .padding(.top, 10).padding(.trailing, 4)
            }
            .frame(height: 200)
        } label: {
            HStack {
                Label("高级配置", systemImage: "slider.horizontal.3").font(.callout.weight(.medium))
                Spacer()
                Text("全局时序 · 当前按键的连发方式").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("gesture.advanced")
    }

    private var timingControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("全局时序").font(.subheadline.weight(.semibold))
            milliseconds("双击间隔", \.doubleClickMilliseconds, range: GestureTiming.doubleClickRange)
            milliseconds("长按阈值", \.longPressMilliseconds, range: GestureTiming.longPressRange)
            milliseconds("连发等待", \.repeatDelayMilliseconds, range: GestureTiming.repeatDelayRange)
            milliseconds("连发间隔", \.repeatIntervalMilliseconds, range: GestureTiming.repeatIntervalRange)
            HStack(alignment: .top) {
                Text("双击间隔从第一次松开计算。长按动作确认后直接按连发间隔重复，不再等待。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button("恢复默认时序") { store.update { $0.gestureTiming = GestureTiming() } }
                    .disabled(store.configuration.gestureTiming == GestureTiming())
            }
        }
    }
    private func milliseconds(_ title: String, _ key: WritableKeyPath<GestureTiming, Int>, range: ClosedRange<Int>) -> some View {
        let binding = Binding<Int>(
            get: { store.configuration.gestureTiming[keyPath: key] },
            set: { value in store.update { $0.gestureTiming[keyPath: key] = min(range.upperBound, max(range.lowerBound, value)) } }
        )
        return HStack(spacing: 6) {
            Text(title).font(.callout)
            Spacer(minLength: 8)
            TextField(title, value: binding, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder).multilineTextAlignment(.trailing).frame(width: 64)
                .accessibilityLabel(title + "毫秒")
            Text("ms").font(.caption).foregroundStyle(.secondary)
            Stepper(title, value: binding, in: range, step: 10).labelsHidden().fixedSize()
                .accessibilityLabel("调整" + title)
        }
    }
    private var behaviorControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("当前按键", selection: Binding(
                get: { selected },
                set: { selected = $0; onSelection() }
            )) {
                if selected == nil { Text("语音键").tag(Optional<RemoteButton>.none) }
                ForEach(RemoteButton.allCases) { Text($0.title).tag(Optional($0)) }
            }
            if let button = selected {
                let c = store.configuration
                let hasClick = c.action(for: button, gesture: .click) != .none
                let hasDouble = c.action(for: button, gesture: .doubleClick) != .none
                let hasLong = c.action(for: button, gesture: .longPress) != .none
                if !hasClick && !hasDouble && !hasLong {
                    Text("先在上方为此键设置动作，再选择连发方式。")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    if hasClick && !hasLong {
                        Picker("单击按住", selection: behavior(button, \.clickRepeat)) {
                            Text("自动").tag(ClickRepeatPreference.automatic)
                            Text("不连发").tag(ClickRepeatPreference.disabled)
                            Text("连发").tag(ClickRepeatPreference.enabled)
                        }
                    }
                    if hasLong {
                        Toggle("长按动作连发", isOn: behavior(button, \.longPressRepeats))
                        Text("已设置长按：判定前不发送单击；按住时执行长按动作。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if hasDouble {
                        Toggle("双击后按住连发", isOn: behavior(button, \.doubleClickHoldRepeats))
                        let explanation = c.behavior(for: button).doubleClickHoldRepeats
                             ? "第二次按下即执行双击动作，按住继续连发，不再转为长按；松开不补发。"
                             : hasLong
                                 ? "双击在第二次松开时执行；第二下持续按住时，仍可转为已设置的长按动作。"
                                 : "双击在第二次松开时执行；第二下持续按住不会连发。"
                        Text(explanation)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if hasClick && !hasLong {
                        Text("自动只连发导航、退格和音量，且没有双击/长按映射。选择连发会反复执行当前单击动作。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Button("恢复此键默认") { store.update { $0.setBehavior(ButtonBehavior(), for: button) } }
                    .disabled(c.behavior(for: button) == ButtonBehavior())
            } else {
                Text("语音键按下开始、松开结束，不使用普通按键的手势与连发参数。")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
    private func behavior<Value>(_ button: RemoteButton, _ key: WritableKeyPath<ButtonBehavior, Value>) -> Binding<Value> {
        Binding(
            get: { store.configuration.behavior(for: button)[keyPath: key] },
            set: { value in
                store.update {
                    var next = $0.behavior(for: button); next[keyPath: key] = value
                    $0.setBehavior(next, for: button)
                }
            }
        )
    }
}
