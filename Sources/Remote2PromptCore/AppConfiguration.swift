import Foundation

/// Versioned persisted preferences. Device identifiers must be macOS UIDs, never transient numeric IDs.
public struct AppConfiguration: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
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

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    /// Missing fields inherit defaults, but unknown future schemas must never be overwritten silently.
    public static func decode(_ data: Data) throws -> Self {
        let configuration = try JSONDecoder().decode(Self.self, from: data)
        guard configuration.schemaVersion == currentSchemaVersion else {
            throw ConfigurationError.unsupportedVersion(configuration.schemaVersion)
        }
        let keys = configuration.bindings.map { "\($0.button.rawValue):\($0.gesture.rawValue)" }
        guard Set(keys).count == keys.count else { throw ConfigurationError.duplicateBinding }
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
}
