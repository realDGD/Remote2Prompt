public struct LoopbackPlaybackHealth: Equatable, Sendable {
    public var running: Bool? = nil
    public var clockFrame: Double? = nil
    public var timingRecoveries = 0
    public var lateSchedules = 0
    public init() {}
}
public struct LoopbackProgress: Equatable, Sendable {
    public var submittedSamples = 0
    public var consumedSamples = 0
    public var pendingSamples = 0
    public var playback = LoopbackPlaybackHealth()
    public init() {}
}
public extension LoopbackPlayback {
    var health: LoopbackPlaybackHealth { LoopbackPlaybackHealth() }
}
public struct VoiceStreamProgress: Equatable, Sendable {
    public var packets = 0
    public var decodedSamples = 0
    public var secondsSincePacket: Int? = nil
    public var signalChanging = false
    public var output = LoopbackProgress()
    public init() {}
}
