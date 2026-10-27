import Foundation

/// Versioned persisted preferences. Device identifiers must be macOS UIDs, never transient numeric IDs.
public struct AppConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2
    public var schemaVersion: Int = currentSchemaVersion
    public var mappingsEnabled = false
    public var preferVirtualInput = false
    public var voiceTrigger: VoiceTrigger = .function
    public var selectedVirtualInputUID: String?
    public var bindings: [KeyBinding] = []

    public init() {}

    public func action(for button: RemoteButton, gesture: ButtonGesture) -> MappedAction {
        bindings.first { $0.button == button && $0.gesture == gesture }?.action ?? .none
    }

    public mutating func setAction(_ action: MappedAction, for button: RemoteButton, gesture: ButtonGesture) {
        bindings.removeAll { $0.button == button && $0.gesture == gesture }
        if action != .none {
            bindings.append(KeyBinding(button: button, gesture: gesture, action: action))
        }
    }

    public mutating func setShortcut(_ shortcut: KeyboardShortcut, for button: RemoteButton, gesture: ButtonGesture) {
        bindings.removeAll { $0.button == button && $0.gesture == gesture }
        bindings.append(KeyBinding(button: button, gesture: gesture, action: .customShortcut, shortcut: shortcut))
    }

    public func invocation(for button: RemoteButton, gesture: ButtonGesture) -> MappedInvocation {
        guard let binding = bindings.first(where: { $0.button == button && $0.gesture == gesture }) else {
            return MappedInvocation(action: .none)
        }
        return MappedInvocation(action: binding.action, shortcut: binding.shortcut)
    }

    /// Fill empty click bindings only; rerunning setup preserves every existing override and gesture.
    public mutating func fillBasicNavigationBindings() {
        let defaults: [(RemoteButton, MappedAction)] = [
            (.up, .arrowUp), (.down, .arrowDown), (.left, .arrowLeft), (.right, .arrowRight),
            (.select, .enter), (.back, .backspace), (.power, .escape),
            (.volumeUp, .volumeUp), (.volumeDown, .volumeDown)
        ]
        for (button, action) in defaults where self.action(for: button, gesture: .click) == .none {
            setAction(action, for: button, gesture: .click)
        }
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Missing fields inherit defaults, but unknown future schemas must never be overwritten silently.
    public static func decode(_ data: Data) throws -> Self {
        var configuration = try JSONDecoder().decode(Self.self, from: data)
        guard (1...currentSchemaVersion).contains(configuration.schemaVersion) else {
            throw ConfigurationError.unsupportedVersion(configuration.schemaVersion)
        }
        let keys = configuration.bindings.map { "\($0.button.rawValue):\($0.gesture.rawValue)" }
        guard Set(keys).count == keys.count else { throw ConfigurationError.duplicateBinding }
        for binding in configuration.bindings {
            if binding.action == .customShortcut && binding.shortcut == nil { throw ConfigurationError.invalidShortcut }
            if let shortcut = binding.shortcut, !shortcut.isValid { throw ConfigurationError.invalidShortcut }
        }
        configuration.schemaVersion = currentSchemaVersion
        return configuration
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, mappingsEnabled, preferVirtualInput, voiceTrigger, selectedVirtualInputUID, bindings
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion
        mappingsEnabled = try values.decodeIfPresent(Bool.self, forKey: .mappingsEnabled) ?? false
        preferVirtualInput = try values.decodeIfPresent(Bool.self, forKey: .preferVirtualInput) ?? false
        voiceTrigger = try values.decodeIfPresent(VoiceTrigger.self, forKey: .voiceTrigger) ?? .function
        selectedVirtualInputUID = try values.decodeIfPresent(String.self, forKey: .selectedVirtualInputUID)
        bindings = try values.decodeIfPresent([KeyBinding].self, forKey: .bindings) ?? []
    }
}

public enum ConfigurationError: Error, Equatable, Sendable {
    case unsupportedVersion(Int)
    case duplicateBinding
    case invalidShortcut
}
