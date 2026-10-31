import AppKit
import VoiRemoteCore
import SwiftUI

extension VoiRemoteCore.KeyboardShortcut {
    var displayTitle: String {
        let names: [UInt16: String] = [
            0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",
            18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",
            36:"↩",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",48:"⇥",49:"空格",50:"`",51:"⌫",53:"Esc",
            54:"右 ⌘",55:"左 ⌘",56:"左 ⇧",58:"左 ⌥",59:"左 ⌃",60:"右 ⇧",61:"右 ⌥",62:"右 ⌃",63:"Fn",
            64:"F17",65:"小数点",67:"×",69:"+",71:"Clear",75:"÷",76:"数字 ↩",78:"−",79:"F18",80:"F19",81:"=",
            82:"数字 0",83:"数字 1",84:"数字 2",85:"数字 3",86:"数字 4",87:"数字 5",88:"数字 6",89:"数字 7",91:"数字 8",92:"数字 9",
            96:"F5",97:"F6",98:"F7",99:"F3",100:"F8",101:"F9",103:"F11",105:"F13",106:"F16",107:"F14",109:"F10",111:"F12",113:"F15",114:"Help",115:"Home",116:"Page Up",117:"⌦",118:"F4",119:"End",120:"F2",121:"Page Down",122:"F1",123:"←",124:"→",125:"↓",126:"↑"
        ]
        var title = ""
        if modifiers.contains(.control) { title += "⌃" }
        if modifiers.contains(.option) { title += "⌥" }
        let plus = keyCode == 24 && modifiers.contains(.shift)
        if modifiers.contains(.shift) && !plus { title += "⇧" }
        if modifiers.contains(.command) { title += "⌘" }
        if modifiers.contains(.function) { title += "Fn " }
        return title + (plus ? "+" : names[keyCode] ?? "键码 \(keyCode)")
    }
}

enum ShortcutEditResult {
    case cancelled, cleared
    case confirmed(VoiRemoteCore.KeyboardShortcut)
}

struct ShortcutCaptureView: View {
    let initial: VoiRemoteCore.KeyboardShortcut?
    var context: String? = nil
    let onFinish: (ShortcutEditResult) -> Void
    @ViewState private var candidate: VoiRemoteCore.KeyboardShortcut?
    @ViewState private var recording = true
    @ViewState private var resetToken = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("录入快捷键").font(.title2.bold())
            if let context { Text(context).font(.callout.weight(.medium)).foregroundStyle(.secondary) }
            Text("按下单键、组合键，或按下并松开一个左右修饰键。录入只在当前窗口内生效。")
                .foregroundStyle(.secondary)
            Text(candidate?.displayTitle ?? "未设置快捷键")
                .font(.system(size: 26, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity, minHeight: 56)
                .accessibilityLabel("候选快捷键：\(candidate?.displayTitle ?? "空")")
            LocalShortcutRecorder(recording: recording, resetToken: resetToken, onCapture: {
                candidate = $0; recording = false
            }, onCancel: { onFinish(.cancelled) })
            .frame(height: 38)
            .overlay(Text(recording ? "正在监听，请按快捷键…" : "已录入，确认后保存").foregroundStyle(.secondary).allowsHitTesting(false))
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Button("清空") { candidate = nil; recording = false; resetToken += 1 }
                Button("重新录入") { resetToken += 1; recording = true }
                Spacer()
                Button("取消") { onFinish(.cancelled) }.keyboardShortcut(.cancelAction)
                Button("确认") { onFinish(candidate.map(ShortcutEditResult.confirmed) ?? .cleared) }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
            Text("清空只修改候选；点击确认后才清除原映射，取消保留原设置。")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(24).frame(width: 500)
        .onAppear { candidate = initial }
    }
}

private struct LocalShortcutRecorder: NSViewRepresentable {
    let recording: Bool
    let resetToken: Int
    let onCapture: (VoiRemoteCore.KeyboardShortcut) -> Void
    let onCancel: () -> Void
    func makeNSView(context: Context) -> RecorderView { RecorderView() }
    func updateNSView(_ view: RecorderView, context: Context) {
        view.onCapture = onCapture; view.onCancel = onCancel
        view.recording = recording
        if view.resetToken != resetToken { view.resetToken = resetToken; view.reset() }
        if recording {
            DispatchQueue.main.async { if view.recording { view.window?.makeFirstResponder(view) } }
        } else if view.window?.firstResponder === view { view.window?.makeFirstResponder(nil) }
    }
}

private final class RecorderView: NSView {
    var onCapture: ((VoiRemoteCore.KeyboardShortcut) -> Void)?
    var onCancel: (() -> Void)?
    var recording = true
    var resetToken = 0
    private var modifiersDown: Set<UInt16> = []
    private var hadModifierChord = false
    override var acceptsFirstResponder: Bool { recording }
    func reset() { modifiersDown.removeAll(); hadModifierChord = false }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, window?.firstResponder === self else { return false }
        keyDown(with: event); return true
    }
    override func keyDown(with event: NSEvent) {
        guard recording, !event.isARepeat else { return }
        if event.keyCode == 53 && event.modifierFlags.intersection([.command, .control, .option, .shift, .function]).isEmpty {
            onCancel?(); return
        }
        var modifiers: ShortcutModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.function) && !(123...126).contains(event.keyCode) { modifiers.insert(.function) }
        onCapture?(VoiRemoteCore.KeyboardShortcut(keyCode: event.keyCode, modifiers: modifiers))
    }
    override func flagsChanged(with event: NSEvent) {
        guard recording, [54,55,56,58,59,60,61,62,63].contains(event.keyCode) else { return }
        if modifiersDown.remove(event.keyCode) != nil {
            if modifiersDown.isEmpty && !hadModifierChord { onCapture?(VoiRemoteCore.KeyboardShortcut(keyCode: event.keyCode)) }
            if modifiersDown.isEmpty { hadModifierChord = false }
        } else {
            modifiersDown.insert(event.keyCode)
            if modifiersDown.count > 1 { hadModifierChord = true }
        }
    }
}
