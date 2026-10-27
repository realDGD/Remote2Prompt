/// The key sent to a target dictation app, rather than a global keyboard listener.
public enum VoiceTrigger: String, CaseIterable, Codable, Sendable, Identifiable {
    case function, leftControl, rightControl, leftCommand, rightCommand, leftOption, rightOption
    public var id: String { rawValue }

    public var virtualKeyCode: UInt16 {
        switch self {
        case .function: 63
        case .leftControl: 59
        case .rightControl: 62
        case .leftCommand: 55
        case .rightCommand: 54
        case .leftOption: 58
        case .rightOption: 61
        }
    }
}

/// Intent for a future CoreGraphics adapter. No system event is posted by this module.
public struct VoiceKeyEvent: Equatable, Sendable {
    public let trigger: VoiceTrigger
    public let isDown: Bool
    public init(trigger: VoiceTrigger, isDown: Bool) { self.trigger = trigger; self.isDown = isDown }
}

/// Overlapping sessions share one held key. The first trigger stays latched until the last release.
public struct VoiceSession: Sendable {
    private var owners: Set<String> = []
    public private(set) var heldTrigger: VoiceTrigger?

    public init() {}

    public mutating func begin(owner: String, trigger: VoiceTrigger) -> [VoiceKeyEvent] {
        guard owners.insert(owner).inserted, heldTrigger == nil else { return [] }
        heldTrigger = trigger
        return [VoiceKeyEvent(trigger: trigger, isDown: true)]
    }

    public mutating func end(owner: String) -> [VoiceKeyEvent] {
        guard owners.remove(owner) != nil, owners.isEmpty else { return [] }
        return release()
    }

    /// Use for shutdown, permission loss, or output failure. The adapter must deliver the returned release.
    public mutating func cancelAll() -> [VoiceKeyEvent] {
        owners.removeAll()
        return release()
    }

    private mutating func release() -> [VoiceKeyEvent] {
        guard let trigger = heldTrigger else { return [] }
        heldTrigger = nil
        return [VoiceKeyEvent(trigger: trigger, isDown: false)]
    }
}
