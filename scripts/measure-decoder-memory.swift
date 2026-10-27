import Foundation

/// Compile alongside Sources/Remote2PromptCore/RemoteVoiceProtocol.swift; no hardware or audio output.
@main
enum DecoderMemoryMeasurement {
    static func main() throws {
        var decoder = try RemoteVoiceDecoder(frameBytes: 120)
        let samples = try decoder.append(Data(repeating: 0x17, count: 4096))
        let digest = samples.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64(UInt16(bitPattern: $1))) &* 1099511628211 }
        print("samples=\(samples.count) pending=\(decoder.pendingBytes.count) retainedCapacity=\(decoder.pendingBytes.capacity)")
        print("digest=\(digest) predictor=\(decoder.predictor) index=\(decoder.stepIndex)")
        try decoder.reset()
        print("afterResetCapacity=\(decoder.pendingBytes.capacity)")
    }
}
