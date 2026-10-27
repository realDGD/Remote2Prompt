/// A physical button identifier, independent of a remote's HID report layout.
public enum RemoteButton: String, CaseIterable, Codable, Sendable, Identifiable {
    case up, down, left, right, select, back, home, menu, volumeUp, volumeDown, power
    public var id: String { rawValue }
}

/// Gestures supported by the planned HID dispatcher; voice has a separate immediate lifecycle.
public enum ButtonGesture: String, CaseIterable, Codable, Sendable, Identifiable {
    case click, doubleClick, longPress
    public var id: String { rawValue }
}

public enum MappedAction: String, CaseIterable, Codable, Sendable, Identifiable {
    case none, arrowUp, arrowDown, arrowLeft, arrowRight, enter, escape, backspace
    case copy, paste, commandTab, volumeUp, volumeDown, mute, playPause
    public var id: String { rawValue }
}

public struct KeyBinding: Codable, Equatable, Sendable {
    public var button: RemoteButton
    public var gesture: ButtonGesture
    public var action: MappedAction

    public init(button: RemoteButton, gesture: ButtonGesture, action: MappedAction) {
        self.button = button
        self.gesture = gesture
        self.action = action
    }
}
