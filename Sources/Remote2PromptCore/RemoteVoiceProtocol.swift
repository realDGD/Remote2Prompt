import Foundation

public enum VoiceProtocolFailure: Error, Equatable, Sendable {
    case malformed, unsupportedCodec, invalidFrameSize, invalidSync, oversizedPacket
}

/// Protocol constants and packet facts; no Bluetooth objects or device identifiers.
public enum RemoteVoiceProtocol {
    public static let service = "AB5E0001-5A21-4F05-BC7D-AF01F617B664"
    public static let transmit = "AB5E0002-5A21-4F05-BC7D-AF01F617B664"
    public static let audio = "AB5E0003-5A21-4F05-BC7D-AF01F617B664"
    public static let control = "AB5E0004-5A21-4F05-BC7D-AF01F617B664"
    public static let capabilitiesRequest = Data([10, 1, 0, 0, 3, 3])
    public static let openMicrophone = Data([12, 0])
    public static func closeMicrophone(session: UInt8) -> Data { Data([13, session]) }
}

public struct VoiceCapabilities: Equatable, Sendable {
    public let version: UInt16
    public let frameBytes: Int
    public init(packet: Data) throws {
        let bytes = Array(packet)
        guard bytes.count >= 7, bytes[0] == 11 else { throw VoiceProtocolFailure.malformed }
        version = UInt16(bytes[1]) << 8 | UInt16(bytes[2])
        let codecs = bytes[3] == 0 && bytes.count >= 9 ? bytes[4] : bytes[3]
        guard version >= 0x0100, codecs & 2 != 0 else { throw VoiceProtocolFailure.unsupportedCodec }
        let declared = Int(bytes[5]) << 8 | Int(bytes[6])
        frameBytes = declared == 0 ? 120 : declared
        guard (1...1024).contains(frameBytes) else { throw VoiceProtocolFailure.invalidFrameSize }
    }
}

/// Streaming IMA/DVI ADPCM, high nibble first for RC001/RC003. Each encoded nibble yields one sample.
public struct RemoteVoiceDecoder: Sendable {
    private static let steps = [7,8,9,10,11,12,13,14,16,17,19,21,23,25,28,31,34,37,41,45,50,55,60,66,73,80,88,97,107,118,130,143,157,173,190,209,230,253,279,307,337,371,408,449,494,544,598,658,724,796,876,963,1060,1166,1282,1411,1552,1707,1878,2066,2272,2499,2749,3024,3327,3660,4026,4428,4871,5358,5894,6484,7132,7845,8630,9493,10442,11487,12635,13899,15289,16818,18500,20350,22385,24623,27086,29794,32767]
    private static let changes = [-1,-1,-1,-1,2,4,6,8]
    public private(set) var predictor = 0
    public private(set) var stepIndex = 0
    public private(set) var pendingBytes: [UInt8] = []
    public let frameBytes: Int

    public init(frameBytes: Int) throws {
        guard (1...1024).contains(frameBytes) else { throw VoiceProtocolFailure.invalidFrameSize }
        self.frameBytes = frameBytes
    }
    public mutating func reset(predictor: Int16 = 0, stepIndex: Int = 0) throws {
        guard (0...88).contains(stepIndex) else { throw VoiceProtocolFailure.invalidSync }
        self.predictor = Int(predictor); self.stepIndex = stepIndex; pendingBytes.removeAll(keepingCapacity: true)
    }
    public mutating func synchronize(packet: Data) throws {
        let bytes = Array(packet)
        guard bytes.count >= 7, bytes[0] == 10 else { throw VoiceProtocolFailure.malformed }
        let value = Int16(bitPattern: UInt16(bytes[4]) << 8 | UInt16(bytes[5]))
        try reset(predictor: value, stepIndex: Int(bytes[6]))
    }
    public mutating func append(_ packet: Data) throws -> [Int16] {
        guard packet.count <= 4096 else { throw VoiceProtocolFailure.oversizedPacket }
        pendingBytes.append(contentsOf: packet)
        let completeBytes = pendingBytes.count / frameBytes * frameBytes
        var samples: [Int16] = []; samples.reserveCapacity(completeBytes * 2)
        for byte in pendingBytes.prefix(completeBytes) {
            samples.append(decode(Int(byte >> 4)))
            samples.append(decode(Int(byte & 15)))
        }
        pendingBytes.removeFirst(completeBytes)
        return samples
    }
    private mutating func decode(_ value: Int) -> Int16 {
        let step = Self.steps[stepIndex]
        var magnitude = step / 8
        if value & 1 != 0 { magnitude += step / 4 }
        if value & 2 != 0 { magnitude += step / 2 }
        if value & 4 != 0 { magnitude += step }
        predictor = min(32767, max(-32768, predictor + (value & 8 == 0 ? magnitude : -magnitude)))
        stepIndex = min(88, max(0, stepIndex + Self.changes[value & 7]))
        return Int16(predictor)
    }
}
