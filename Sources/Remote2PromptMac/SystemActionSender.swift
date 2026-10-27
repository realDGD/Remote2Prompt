import AppKit
import ApplicationServices
import IOKit.hidsystem
import Remote2PromptCore

public enum ActionFailure: Error, LocalizedError {
    case accessibility, eventCreation, physicalModifier, conflictingVoice
    public var errorDescription: String? {
        switch self {
        case .accessibility: "发送按键需要辅助功能权限。"
        case .eventCreation: "无法创建系统按键事件。"
        case .physicalModifier: "语音触发键正被实体键盘按住，请松开后重试。"
        case .conflictingVoice: "上一语音按键尚未释放。"
        }
    }
}

/// The poster is injectable; event construction checks never need to send keys to the desktop.
@MainActor
public final class SystemActionSender {
    public static let eventTag: Int64 = 0x523250524F4D5054
    private let post: (CGEvent) -> Void
    private let permission: () -> Bool
    private let physicalKeyDown: (UInt16) -> Bool
    private var heldVoice: VoiceTrigger?

    public init(
        permission: @escaping () -> Bool = { AXIsProcessTrusted() },
        physicalKeyDown: @escaping (UInt16) -> Bool = { CGEventSource.keyState(.hidSystemState, key: $0) },
        post: @escaping (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }
    ) { self.permission = permission; self.physicalKeyDown = physicalKeyDown; self.post = post }

    public func perform(_ invocation: MappedInvocation) throws {
        guard invocation.action != .none else { return }
        guard permission() else { throw ActionFailure.accessibility }
        let shortcut: KeyboardShortcut?
        switch invocation.action {
        case .none: return
        case .arrowUp: shortcut = KeyboardShortcut(keyCode: 126)
        case .arrowDown: shortcut = KeyboardShortcut(keyCode: 125)
        case .arrowLeft: shortcut = KeyboardShortcut(keyCode: 123)
        case .arrowRight: shortcut = KeyboardShortcut(keyCode: 124)
        case .enter: shortcut = KeyboardShortcut(keyCode: 36)
        case .escape: shortcut = KeyboardShortcut(keyCode: 53)
        case .backspace: shortcut = KeyboardShortcut(keyCode: 51)
        case .copy: shortcut = KeyboardShortcut(keyCode: 8, modifiers: .command)
        case .paste: shortcut = KeyboardShortcut(keyCode: 9, modifiers: .command)
        case .commandTab: shortcut = KeyboardShortcut(keyCode: 48, modifiers: .command)
        case .customShortcut: shortcut = invocation.shortcut
        case .volumeUp: try media(0); return
        case .volumeDown: try media(1); return
        case .mute: try media(7); return
        case .playPause: try media(16); return
        }
        guard let shortcut, shortcut.isValid else { throw ActionFailure.eventCreation }
        let down = try keyboard(code: shortcut.keyCode, down: true, flags: flags(shortcut.modifiers))
        let up = try keyboard(code: shortcut.keyCode, down: false, flags: flags(shortcut.modifiers))
        if let modifier = modifierFlags(shortcut.keyCode) {
            down.type = .flagsChanged; up.type = .flagsChanged
            down.flags.formUnion(modifier); up.flags = []
        }
        post(down); post(up)
    }

    public func voice(_ event: VoiceKeyEvent) throws {
        let trigger = event.trigger
        if event.isDown {
            guard permission() else { throw ActionFailure.accessibility }
            if heldVoice == trigger { return }
            guard heldVoice == nil else { throw ActionFailure.conflictingVoice }
            guard !physicalKeyDown(trigger.virtualKeyCode) else { throw ActionFailure.physicalModifier }
            let key = try keyboard(code: trigger.virtualKeyCode, down: true, flags: modifierFlags(trigger.virtualKeyCode) ?? [])
            key.type = .flagsChanged
            heldVoice = trigger
            post(key)
        } else {
            guard heldVoice == trigger else { return }
            let key = try keyboard(code: trigger.virtualKeyCode, down: false, flags: CGEventSource.flagsState(.hidSystemState))
            key.type = .flagsChanged
            post(key)
            heldVoice = nil
        }
    }

    public func releaseAll() throws {
        guard let trigger = heldVoice else { return }
        try voice(VoiceKeyEvent(trigger: trigger, isDown: false))
    }

    private func keyboard(code: UInt16, down: Bool, flags: CGEventFlags) throws -> CGEvent {
        guard let event = CGEvent(keyboardEventSource: CGEventSource(stateID: .privateState), virtualKey: code, keyDown: down) else { throw ActionFailure.eventCreation }
        event.flags = flags
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventTag)
        return event
    }

    private func media(_ code: Int) throws {
        let events = try [0xA, 0xB].map { phase -> CGEvent in
            guard let event = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(phase << 8)), timestamp: 0, windowNumber: 0, context: nil, subtype: 8, data1: (code << 16) | (phase << 8), data2: -1)?.cgEvent else { throw ActionFailure.eventCreation }
            event.setIntegerValueField(.eventSourceUserData, value: Self.eventTag)
            return event
        }
        events.forEach(post)
    }

    private func flags(_ modifiers: ShortcutModifiers) -> CGEventFlags {
        var result: CGEventFlags = []
        if modifiers.contains(.command) { result.insert(.maskCommand) }
        if modifiers.contains(.control) { result.insert(.maskControl) }
        if modifiers.contains(.option) { result.insert(.maskAlternate) }
        if modifiers.contains(.shift) { result.insert(.maskShift) }
        if modifiers.contains(.function) { result.insert(.maskSecondaryFn) }
        return result
    }

    private func modifierFlags(_ code: UInt16) -> CGEventFlags? {
        switch code {
        case 59: [.maskControl, CGEventFlags(rawValue: UInt64(NX_DEVICELCTLKEYMASK))]
        case 62: [.maskControl, CGEventFlags(rawValue: UInt64(NX_DEVICERCTLKEYMASK))]
        case 55: [.maskCommand, CGEventFlags(rawValue: UInt64(NX_DEVICELCMDKEYMASK))]
        case 54: [.maskCommand, CGEventFlags(rawValue: UInt64(NX_DEVICERCMDKEYMASK))]
        case 58: [.maskAlternate, CGEventFlags(rawValue: UInt64(NX_DEVICELALTKEYMASK))]
        case 61: [.maskAlternate, CGEventFlags(rawValue: UInt64(NX_DEVICERALTKEYMASK))]
        case 56: [.maskShift, CGEventFlags(rawValue: UInt64(NX_DEVICELSHIFTKEYMASK))]
        case 60: [.maskShift, CGEventFlags(rawValue: UInt64(NX_DEVICERSHIFTKEYMASK))]
        case 63: .maskSecondaryFn
        default: nil
        }
    }
}
