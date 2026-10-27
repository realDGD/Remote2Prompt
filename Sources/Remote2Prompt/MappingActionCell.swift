import Remote2PromptCore
import SwiftUI

struct MappingActionCell: View {
    let button: RemoteButton
    let gesture: ButtonGesture
    let invocation: MappedInvocation
    let choose: (MappedAction) -> Void
    let record: () -> Void

    private var name: String { "\(button.title)键\(gesture.title)" }
    private var isEmpty: Bool { invocation.action == .none }

    var body: some View {
        HStack(spacing: 0) {
            if invocation.action == .customShortcut {
                Button(action: record) {
                    Text(invocation.shortcut?.displayTitle ?? "录入快捷键")
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 10).frame(height: 30).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("编辑\(name)快捷键")
                .help("点按重新录入\(name)的快捷键")
                actionMenu(compact: true)
            } else {
                actionMenu(compact: false)
                Button(action: record) {
                    Image(systemName: "keyboard").frame(width: 27, height: 30).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .accessibilityLabel("录入\(name)快捷键").help("直接录入快捷键")
            }
            if !isEmpty {
                Button { choose(.none) } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 11))
                        .frame(width: 23, height: 30).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(.tertiary)
                .accessibilityLabel("清除\(name)动作").help("清除此动作")
            }
        }
        .frame(maxWidth: .infinity)
        .background(isEmpty ? Color.primary.opacity(0.025) : Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.primary.opacity(isEmpty ? 0.04 : 0.09)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
        .accessibilityIdentifier("mapping.\(button.rawValue).\(gesture.rawValue)")
    }

    private func actionMenu(compact: Bool) -> some View {
        Menu {
            Button("录入快捷键…", systemImage: "keyboard", action: record)
            Divider()
            Section("导航") {
                ForEach([MappedAction.arrowUp, .arrowDown, .arrowLeft, .arrowRight, .enter, .escape, .backspace]) { action in choice(action) }
            }
            Section("编辑与应用") {
                ForEach([MappedAction.copy, .paste, .commandTab]) { action in choice(action) }
            }
            Section("媒体与音量") {
                ForEach([MappedAction.volumeUp, .volumeDown, .mute, .playPause]) { action in choice(action) }
            }
            Divider()
            choice(.none)
        } label: {
            HStack(spacing: 5) {
                if !compact {
                    Text(isEmpty ? "设置动作" : invocation.action.title)
                        .foregroundStyle(isEmpty ? .secondary : .primary)
                        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                }
                Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .font(.callout).padding(.leading, compact ? 7 : 10).padding(.trailing, 7)
            .frame(height: 30).contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden)
        .fixedSize(horizontal: compact, vertical: false)
        .accessibilityLabel("选择\(name)动作")
        .accessibilityValue(isEmpty ? "未设置" : invocation.shortcut?.displayTitle ?? invocation.action.title)
    }

    @ViewBuilder private func choice(_ action: MappedAction) -> some View {
        Button { choose(action) } label: {
            if invocation.action == action { Label(action.title, systemImage: "checkmark") }
            else { Text(action.title) }
        }
    }
}
