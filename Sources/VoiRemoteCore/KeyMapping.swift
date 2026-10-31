/// A physical button identifier, independent of a remote's HID report layout.
public enum RemoteButton: String, CaseIterable, Codable, Sendable, Identifiable {
    case up, down, left, right, select, back, home, menu, tv, volumeUp, volumeDown, power
    public var id: String { rawValue }
}

/// Gestures supported by the planned HID dispatcher; voice has a separate immediate lifecycle.
public enum ButtonGesture: String, CaseIterable, Codable, Sendable, Identifiable {
    case click, doubleClick, longPress
    public var id: String { rawValue }
}

public enum MappedAction: String, CaseIterable, Codable, Sendable, Identifiable {
    case none, arrowUp, arrowDown, arrowLeft, arrowRight, enter, escape, backspace
    case copy, paste, commandTab, volumeUp, volumeDown, mute, playPause, customShortcut
    public var id: String { rawValue }
}

public struct KeyBinding: Codable, Equatable, Sendable {
    public var button: RemoteButton
    public var gesture: ButtonGesture
    public var action: MappedAction
    public var shortcut: KeyboardShortcut?

    public init(button: RemoteButton, gesture: ButtonGesture, action: MappedAction, shortcut: KeyboardShortcut? = nil) {
        self.button = button
        self.gesture = gesture
        self.action = action
        self.shortcut = shortcut
    }
}

public struct ShortcutModifiers: OptionSet, Codable, Equatable, Hashable, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let command = Self(rawValue: 1)
    public static let control = Self(rawValue: 2)
    public static let option = Self(rawValue: 4)
    public static let shift = Self(rawValue: 8)
    public static let function = Self(rawValue: 16)
}

public struct KeyboardShortcut: Codable, Equatable, Sendable {
    public let keyCode: UInt16
    public let modifiers: ShortcutModifiers
    public init(keyCode: UInt16, modifiers: ShortcutModifiers = []) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
    public var isValid: Bool { keyCode <= 127 && modifiers.rawValue & ~UInt8(31) == 0 }
}

public struct MappedInvocation: Equatable, Sendable {
    public let action: MappedAction
    public let shortcut: KeyboardShortcut?
    public init(action: MappedAction, shortcut: KeyboardShortcut? = nil) {
        self.action = action
        self.shortcut = shortcut
    }
    public var allowsRepeat: Bool {
        if [.arrowUp, .arrowDown, .arrowLeft, .arrowRight, .backspace, .volumeUp, .volumeDown].contains(action) { return true }
        return action == .customShortcut && shortcut.map { $0.modifiers.isEmpty && [51, 123, 124, 125, 126].contains($0.keyCode) } == true
    }
    /// The UI and system adapter share the exact key that an ordinary action resolves to.
    public var resolvedShortcut: KeyboardShortcut? {
        switch action {
        case .arrowUp: KeyboardShortcut(keyCode: 126)
        case .arrowDown: KeyboardShortcut(keyCode: 125)
        case .arrowLeft: KeyboardShortcut(keyCode: 123)
        case .arrowRight: KeyboardShortcut(keyCode: 124)
        case .enter: KeyboardShortcut(keyCode: 36)
        case .escape: KeyboardShortcut(keyCode: 53)
        case .backspace: KeyboardShortcut(keyCode: 51)
        case .copy: KeyboardShortcut(keyCode: 8, modifiers: .command)
        case .paste: KeyboardShortcut(keyCode: 9, modifiers: .command)
        case .commandTab: KeyboardShortcut(keyCode: 48, modifiers: .command)
        case .customShortcut: shortcut
        case .none, .volumeUp, .volumeDown, .mute, .playPause: nil
        }
    }
}
