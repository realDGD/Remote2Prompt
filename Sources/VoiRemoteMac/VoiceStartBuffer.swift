/// Bounded PCM preroll while a default-input switch is waiting for confirmation.
public struct VoiceStartBuffer: Sendable {
    private var samples: [Int16] = []
    public init() {}
    public mutating func append(_ value: [Int16]) throws {
        guard samples.count + value.count <= 32000 else { throw LoopbackFailure.overflow }
        samples.append(contentsOf: value)
    }
    public mutating func take() -> [Int16] {
        let value = samples; samples.removeAll(keepingCapacity: false); return value
    }
    public mutating func clear() { samples.removeAll(keepingCapacity: false) }
}
