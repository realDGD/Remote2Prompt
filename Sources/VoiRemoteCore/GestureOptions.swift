import Foundation

/// Milliseconds in storage/UI; recognition converts them to the supplied monotonic clock.
public struct GestureTiming: Codable, Equatable, Sendable {
    public var doubleClickMilliseconds = 300
    public var longPressMilliseconds = 550
    public var repeatDelayMilliseconds = 450
    public var repeatIntervalMilliseconds = 80
    public init() {}
    public static let doubleClickRange = 100...1000
    public static let longPressRange = 150...3000
    public static let repeatDelayRange = 100...3000
    public static let repeatIntervalRange = 30...1000
    public var isValid: Bool {
        Self.doubleClickRange.contains(doubleClickMilliseconds) && Self.longPressRange.contains(longPressMilliseconds)
            && Self.repeatDelayRange.contains(repeatDelayMilliseconds) && Self.repeatIntervalRange.contains(repeatIntervalMilliseconds)
    }
    public var doubleClickDelay: Double { Double(doubleClickMilliseconds) / 1000 }
    public var longPressDelay: Double { Double(longPressMilliseconds) / 1000 }
    public var repeatDelay: Double { Double(repeatDelayMilliseconds) / 1000 }
    public var repeatInterval: Double { Double(repeatIntervalMilliseconds) / 1000 }
    private enum CodingKeys: String, CodingKey {
        case doubleClickMilliseconds, longPressMilliseconds, repeatDelayMilliseconds, repeatIntervalMilliseconds
    }
    public init(from decoder: any Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        doubleClickMilliseconds = try v.decodeIfPresent(Int.self, forKey: .doubleClickMilliseconds) ?? 300
        longPressMilliseconds = try v.decodeIfPresent(Int.self, forKey: .longPressMilliseconds) ?? 550
        repeatDelayMilliseconds = try v.decodeIfPresent(Int.self, forKey: .repeatDelayMilliseconds) ?? 450
        repeatIntervalMilliseconds = try v.decodeIfPresent(Int.self, forKey: .repeatIntervalMilliseconds) ?? 80
    }
}

public enum ClickRepeatPreference: String, Codable, CaseIterable, Sendable {
    case automatic, disabled, enabled
}
public struct ButtonBehavior: Codable, Equatable, Sendable {
    public var clickRepeat: ClickRepeatPreference = .automatic
    public var longPressRepeats = false
    public var doubleClickHoldRepeats = false
    public init() {}
    private enum CodingKeys: String, CodingKey { case clickRepeat, longPressRepeats, doubleClickHoldRepeats }
    public init(from decoder: any Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        clickRepeat = try v.decodeIfPresent(ClickRepeatPreference.self, forKey: .clickRepeat) ?? .automatic
        longPressRepeats = try v.decodeIfPresent(Bool.self, forKey: .longPressRepeats) ?? false
        doubleClickHoldRepeats = try v.decodeIfPresent(Bool.self, forKey: .doubleClickHoldRepeats) ?? false
    }
}
public struct ButtonBehaviorOverride: Codable, Equatable, Sendable {
    public var button: RemoteButton
    public var behavior: ButtonBehavior
    public init(button: RemoteButton, behavior: ButtonBehavior) { self.button = button; self.behavior = behavior }
}
