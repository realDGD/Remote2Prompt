/// A live stream cannot keep scheduling buffers behind a device clock after an underrun.
/// Times are 16 kHz PCM frames; recovery inserts a 50 ms lead without dropping queued PCM.
public struct PCMPlayoutClock: Sendable {
    private var endFrame: Double?
    public init() {}
    public mutating func reset() { endFrame = nil }
    public func recoveryStart(currentFrame: Double?) -> Double? {
        guard let endFrame, let currentFrame, currentFrame.isFinite, currentFrame >= 0,
              endFrame < currentFrame + 160 else { return nil }
        return currentFrame + 800
    }
    public mutating func enqueued(startFrame: Double, frameCount: Int) {
        guard startFrame.isFinite, startFrame >= 0, frameCount > 0 else { endFrame = nil; return }
        endFrame = startFrame + Double(frameCount)
    }
}
