import AppKit
import Remote2PromptCore
import SwiftUI

extension Remote2PromptCore.KeyboardShortcut {
    var displayTitle: String {
        let names: [UInt16: String] = [36: "↩", 48: "⇥", 49: "空格", 51: "⌫", 53: "Esc", 54: "右 ⌘", 55: "左 ⌘", 56: "左 ⇧", 58: "左 ⌥", 59: "左 ⌃", 60: "右 ⇧", 61: "右 ⌥", 62: "右 ⌃", 63: "Fn", 123: "←", 124: "→", 125: "↓", 126: "↑", 8: "C", 9: "V"]
        var title = ""
        if modifiers.contains(.control) { title += "⌃" }
        if modifiers.contains(.option) { title += "⌥" }
        if modifiers.contains(.shift) { title += "⇧" }
        if modifiers.contains(.command) { title += "⌘" }
        if modifiers.contains(.function) { title += "Fn " }
        return title + (names[keyCode] ?? "键码 \(keyCode)")
    }
}

struct ShortcutCaptureView: View {
    let onCapture: (Remote2PromptCore.KeyboardShortcut?) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("按下要映射的快捷键").font(.headline)
            Text("支持单键、组合键和单独的左右修饰键。Escape 取消；录入只在此窗口内进行。")
                .foregroundStyle(.secondary)
            LocalShortcutRecorder(onCapture: onCapture).frame(height: 50)
            Button("取消") { onCapture(nil) }
        }
        .padding(24).frame(width: 400)
    }
}

private struct LocalShortcutRecorder: NSViewRepresentable {
    let onCapture: (Remote2PromptCore.KeyboardShortcut?) -> Void
    func makeNSView(context: Context) -> RecorderView {
        let view = RecorderView(); view.onCapture = onCapture
        return view
    }
    func updateNSView(_ view: RecorderView, context: Context) { view.onCapture = onCapture }
}

private final class RecorderView: NSView {
    var onCapture: ((Remote2PromptCore.KeyboardShortcut?) -> Void)?
    private var modifierCandidate: UInt16?
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        keyDown(with: event); return true
    }
    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        if event.keyCode == 53 && event.modifierFlags.intersection([.command, .control, .option, .shift, .function]).isEmpty {
            onCapture?(nil); return
        }
        var modifiers: ShortcutModifiers = []
        if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
        if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
        if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
        if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
        if event.modifierFlags.contains(.function) && !(123...126).contains(event.keyCode) { modifiers.insert(.function) }
        onCapture?(Remote2PromptCore.KeyboardShortcut(keyCode: event.keyCode, modifiers: modifiers))
    }
    override func flagsChanged(with event: NSEvent) {
        guard [54, 55, 56, 58, 59, 60, 61, 62, 63].contains(event.keyCode) else { return }
        if modifierCandidate == event.keyCode {
            onCapture?(Remote2PromptCore.KeyboardShortcut(keyCode: event.keyCode))
            modifierCandidate = nil
        } else { modifierCandidate = event.keyCode }
    }
}
