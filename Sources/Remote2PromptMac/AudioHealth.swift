import Foundation

/// Serial-writer policy. Silence still advances the playback clock; idle queues need not run.
struct OutputHealthMonitor {
    private var observedAt: TimeInterval?
    private var progressedAt: TimeInterval?
    private var previous = LoopbackProgress()

    mutating func reset() { self = Self() }
    mutating func failure(_ value: LoopbackProgress, at now: TimeInterval) -> LoopbackFailure? {
        if let code = value.playback.converterError, code != 0 { return .configure(code) }
        guard value.pendingSamples > 0 else { reset(); return nil }
        if observedAt == nil { observedAt = now; progressedAt = now }
        defer { previous = value }
        if value.consumedSamples != previous.consumedSamples
            || (value.playback.clockFrame ?? 0) > (previous.playback.clockFrame ?? 0) {
            progressedAt = now
        }
        if value.playback.running == false, now - (observedAt ?? now) >= 0.5 { return .playbackStopped }
        if now - (progressedAt ?? now) >= 3 { return .playbackStalled }
        return nil
    }
}

/// One recovery owner, including failures immediately after successful configuration.
struct AudioRecoveryBudget {
    private(set) var attempts = 0
    private(set) var retryAt: TimeInterval?
    private var healthySince: TimeInterval?
    var exhausted: Bool { attempts >= 3 && retryAt == nil }
    mutating func reset() { self = Self() }
    mutating func failed(at now: TimeInterval) {
        healthySince = nil
        guard attempts < 3 else { retryAt = nil; return }
        retryAt = now + [1.0, 2.0, 4.0][attempts]
        attempts += 1
    }
    mutating func takeRetry(at now: TimeInterval) -> Bool {
        guard let retryAt, now >= retryAt else { return false }
        self.retryAt = nil
        return true
    }
    mutating func observeHealthy(at now: TimeInterval) {
        if healthySince == nil { healthySince = now }
        if now - (healthySince ?? now) >= 10 { reset(); healthySince = now }
    }
}
