import Foundation

/// Reported ATVV reason classifications. Their firmware semantics still require model-specific checks.
public enum RemoteVoiceStopReason: Equatable, Sendable {
    case ordinaryReported, timeLimitReported, unspecified
}

public extension RemoteVoiceProtocol {
    static func stopReason(packet: Data) -> RemoteVoiceStopReason? {
        guard packet.first == 0 else { return nil }
        guard packet.count > 1 else { return .unspecified }
        switch packet[packet.startIndex + 1] {
        case 0x00, 0x02: return .ordinaryReported
        case 0x08: return .timeLimitReported
        default: return .unspecified
        }
    }
}
