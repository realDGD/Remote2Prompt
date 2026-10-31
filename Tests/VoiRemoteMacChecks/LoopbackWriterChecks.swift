import Foundation
import VoiRemoteMac

private final class LockedValue<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value
    init(_ value: Value) { self.value = value }
    func withValue<Result>(_ body: (inout Value) -> Result) -> Result { lock.withLock { body(&value) } }
}

private final class FakeLoopbackPlayback: LoopbackPlayback, @unchecked Sendable {
    private struct State {
        var changed: (@Sendable () -> Void)?
        var consumed: [@Sendable () -> Void] = []
        var drains: [@Sendable (Bool) -> Void] = []
        var holdDrain = false
        var configurations = 0
        var begins = 0
        var validations = 0
        var stops = 0
        var configureError: LoopbackFailure?
        var validationError: LoopbackFailure?
        var health = LoopbackPlaybackHealth()
    }
    private let state = LockedValue(State())
    let validated = DispatchSemaphore(value: 0)
    var configurations: Int { state.withValue { $0.configurations } }
    var begins: Int { state.withValue { $0.begins } }
    var validations: Int { state.withValue { $0.validations } }
    var stops: Int { state.withValue { $0.stops } }
    var health: LoopbackPlaybackHealth { state.withValue { $0.health } }
    func setHealth(_ value: LoopbackPlaybackHealth) { state.withValue { $0.health = value } }
    var notification: @Sendable () -> Void { state.withValue { $0.changed ?? {} } }
    func failConfigure(_ error: LoopbackFailure) { state.withValue { $0.configureError = error } }
    func failValidation(_ error: LoopbackFailure) { state.withValue { $0.validationError = error } }
    func holdDrain() { state.withValue { $0.holdDrain = true } }
    func takeDrains() -> [@Sendable (Bool) -> Void] { state.withValue { let result = $0.drains; $0.drains = []; return result } }
    func takeConsumed() -> [@Sendable () -> Void] { state.withValue { let result = $0.consumed; $0.consumed = []; return result } }
    func configure(uid: String, configurationChanged: @escaping @Sendable () -> Void) throws(LoopbackFailure) {
        let error = state.withValue { $0.configurations += 1; $0.changed = configurationChanged; return $0.configureError }
        if let error { throw error }
    }
    func begin() { state.withValue { $0.begins += 1; $0.consumed = [] } }
    func append(_ samples: [Int16], consumed: @escaping @Sendable () -> Void) throws(LoopbackFailure) { state.withValue { $0.consumed.append(consumed) } }
    func validateRoute() throws(LoopbackFailure) {
        let error = state.withValue { $0.validations += 1; return $0.validationError }
        validated.signal()
        if let error { throw error }
    }
    func finish(completion: @escaping @Sendable (Bool) -> Void) {
        let held = state.withValue { value in
            if value.holdDrain { value.drains.append(completion) }
            return value.holdDrain
        }
        if !held { completion(true) }
    }
    func stop() { state.withValue { $0.stops += 1; $0.consumed = [] } }
}

private func waited<Value>(_ operation: (@escaping @Sendable (Value) -> Void) -> Void) throws -> Value {
    let result = LockedValue<Value?>(nil)
    let done = DispatchSemaphore(value: 0)
    operation { value in result.withValue { $0 = value }; done.signal() }
    try check(done.wait(timeout: .now() + 2) == .success, "Writer callback timed out")
    return result.withValue { $0! }
}
private func configure(_ writer: LoopbackWriter, onFailure: (@Sendable (LoopbackFailure) -> Void)? = nil) throws {
    let result: Result<Void, LoopbackFailure> = try waited { writer.configure(uid: "fixture-loopback", onFailure: onFailure, completion: $0) }
    try result.get()
}
private func append(_ count: Int, to writer: LoopbackWriter) throws -> LoopbackFailure? {
    try waited { writer.append([Int16](repeating: 0, count: count), completion: $0) }
}
private func validate(_ fake: FakeLoopbackPlayback) throws {
    fake.notification()
    try check(fake.validated.wait(timeout: .now() + 2) == .success, "Configuration change did not reach the queue owner")
}

func loopbackWriterChecks() -> [(String, @MainActor () throws -> Void)] {
    [
        ("health accepts a stopped idle queue and rejects a stopped active queue after grace", {
            let fake = FakeLoopbackPlayback(); var health = LoopbackPlaybackHealth(); health.running = false
            fake.setHealth(health)
            let time = LockedValue(0.0)
            let writer = LoopbackWriter(playback: { fake }, clock: { time.withValue { $0 } })
            defer { writer.stop() }
            try configure(writer)
            time.withValue { $0 = 100 }
            let idle: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }
            _ = try idle.get()
            writer.begin(); _ = try append(160, to: writer)
            let starting: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }
            _ = try starting.get()
            time.withValue { $0 = 101 }
            let failed: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }
            guard case .failure(.playbackStopped) = failed else { throw Failure(message: "Stopped active playback was accepted") }
            try check(fake.stops == 1, "Health failure did not dispose its playback")
        }),
        ("health detects frozen playback but accepts clock progress and consumed buffers", {
            let fake = FakeLoopbackPlayback(); var health = LoopbackPlaybackHealth(); health.running = true; health.clockFrame = 0
            fake.setHealth(health); let time = LockedValue(0.0)
            let writer = LoopbackWriter(playback: { fake }, clock: { time.withValue { $0 } })
            defer { writer.stop() }; try configure(writer); writer.begin(); _ = try append(160, to: writer)
            let first: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }; _ = try first.get()
            time.withValue { $0 = 2 }; health.clockFrame = 160; fake.setHealth(health)
            let moving: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }; _ = try moving.get()
            time.withValue { $0 = 4 }
            let grace: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }; _ = try grace.get()
            time.withValue { $0 = 5 }
            let frozen: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }
            guard case .failure(.playbackStalled) = frozen else { throw Failure(message: "Frozen playback was accepted") }
            try configure(writer); writer.begin(); _ = try append(160, to: writer); fake.takeConsumed().forEach { $0() }
            time.withValue { $0 = 100 }
            let idle: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }; _ = try idle.get()
        }),
        ("health reports converter and device failures without restarting from stale notifications", {
            let fake = FakeLoopbackPlayback(); let writer = LoopbackWriter(playback: { fake }); defer { writer.stop() }
            try configure(writer); let stale = fake.notification
            var health = LoopbackPlaybackHealth(); health.converterError = -50; fake.setHealth(health)
            let result: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }
            guard case .failure(.configure(-50)) = result else { throw Failure(message: "Converter error was ignored") }
            stale()
            let snapshot: LoopbackProgress = try waited { writer.snapshot(completion: $0) }
            try check(snapshot.pendingSamples == 0 && fake.configurations == 1 && fake.stops == 1, "Old route restarted disposed output")
            fake.setHealth(LoopbackPlaybackHealth()); try configure(writer); fake.failValidation(.unavailable)
            let lost: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }
            guard case .failure(.unavailable) = lost else { throw Failure(message: "Lost explicit device was accepted") }
            try configure(writer); fake.failValidation(.silenced)
            let muted: Result<LoopbackProgress, LoopbackFailure> = try waited { writer.checkHealth(completion: $0) }
            guard case .failure(.silenced) = muted else { throw Failure(message: "Silenced device was accepted") }
        }),
        ("progress counters reject old callbacks after a new session starts", {
            let fake = FakeLoopbackPlayback(); let writer = LoopbackWriter(playback: { fake })
            defer { writer.stop() }
            try configure(writer); writer.begin(); _ = try append(160, to: writer)
            let old = fake.takeConsumed(); writer.cancel(); writer.begin(); _ = try append(240, to: writer)
            old.forEach { $0() }
            let pending: LoopbackProgress = try waited { writer.snapshot(completion: $0) }
            try check(pending.submittedSamples == 240 && pending.consumedSamples == 0 && pending.pendingSamples == 240, "Old callback polluted current progress")
            fake.takeConsumed().forEach { $0() }
            let done: LoopbackProgress = try waited { writer.snapshot(completion: $0) }
            try check(done.submittedSamples == 240 && done.consumedSamples == 240 && done.pendingSamples == 0, "Progress did not reflect consumed current audio")
        }),
        ("consumed buffers do not release a session before hardware drain confirmation", {
            let fake = FakeLoopbackPlayback(); fake.holdDrain()
            let writer = LoopbackWriter(playback: { fake }); defer { writer.stop() }
            try configure(writer); writer.begin(); _ = try append(160, to: writer)
            fake.takeConsumed().forEach { $0() }
            let result = LockedValue<Bool?>(nil); let done = DispatchSemaphore(value: 0)
            writer.finish { value in result.withValue { $0 = value }; done.signal() }
            _ = try append(0, to: writer)
            try check(result.withValue { $0 == nil }, "Consumption was mistaken for playback completion")
            let drains = fake.takeDrains()
            try check(drains.count == 1, "Hardware drain was not requested exactly once")
            drains.forEach { $0(true) }
            try check(done.wait(timeout: .now() + 2) == .success && result.withValue { $0 == true }, "Hardware drain did not complete the session")
        }),
        ("hardware drain failure is not reported as successful playback", {
            let fake = FakeLoopbackPlayback(); fake.holdDrain()
            let writer = LoopbackWriter(playback: { fake }); defer { writer.stop() }
            try configure(writer)
            let result = LockedValue<Bool?>(nil); let done = DispatchSemaphore(value: 0)
            writer.finish { value in result.withValue { $0 = value }; done.signal() }
            _ = try append(0, to: writer); fake.takeDrains().forEach { $0(false) }
            try check(done.wait(timeout: .now() + 2) == .success && result.withValue { $0 == false }, "Hardware failure falsely drained")
        }),
        ("cancelled hardware drain cannot complete a later voice session", {
            let fake = FakeLoopbackPlayback(); fake.holdDrain()
            let writer = LoopbackWriter(playback: { fake }); defer { writer.stop() }
            try configure(writer)
            let old = LockedValue<Bool?>(nil)
            writer.finish { value in old.withValue { $0 = value } }
            _ = try append(0, to: writer); let stale = fake.takeDrains()
            writer.cancel()
            let result = LockedValue<Bool?>(nil); let done = DispatchSemaphore(value: 0)
            writer.finish { value in result.withValue { $0 = value }; done.signal() }
            _ = try append(0, to: writer); stale.forEach { $0(true) }; _ = try append(0, to: writer)
            try check(old.withValue { $0 == false } && result.withValue { $0 == nil }, "Old drain completed the replacement session")
            fake.takeDrains().forEach { $0(true) }
            try check(done.wait(timeout: .now() + 2) == .success && result.withValue { $0 == true }, "New session did not drain")
        }),
        ("output change validates the same backend without clearing queued audio", {
            let fake = FakeLoopbackPlayback(); let writer = LoopbackWriter(playback: { fake })
            defer { writer.stop() }
            try configure(writer); writer.begin(); try check(try append(160, to: writer) == nil, "Append failed")
            let begins = fake.begins
            try validate(fake)
            try check(fake.configurations == 1 && fake.begins == begins && fake.stops == 0, "Route validation discarded the output or buffers")
            fake.takeConsumed().forEach { $0() }
            let drained: Bool = try waited { writer.finish(completion: $0) }
            try check(drained, "Recovered playback did not drain")
        }),
        ("previous route notifications cannot resume a replacement output", {
            let first = FakeLoopbackPlayback(); let second = FakeLoopbackPlayback()
            let pool = LockedValue([first, second]); let writer = LoopbackWriter(playback: { pool.withValue { $0.removeFirst() } })
            defer { writer.stop() }
            try configure(writer); let oldNotification = first.notification
            try configure(writer); oldNotification()
            try check(try append(0, to: writer) == nil, "Replacement output unavailable")
            try check(first.validations == 0 && second.validations == 0, "Old notification restarted a route")
        }),
        ("stopped output ignores delayed device notifications", {
            let fake = FakeLoopbackPlayback(); let writer = LoopbackWriter(playback: { fake })
            try configure(writer); let notification = fake.notification
            let _: Void = try waited { done in writer.stop { done(()) } }
            notification()
            try check(try append(0, to: writer) != nil && fake.validations == 0, "Stopped output was resurrected")
        }),
        ("failed route validation cancels drain and reports the route failure once", {
            let fake = FakeLoopbackPlayback(); let writer = LoopbackWriter(playback: { fake })
            defer { writer.stop() }
            let failures = LockedValue(0); let failed = DispatchSemaphore(value: 0)
            try configure(writer, onFailure: { _ in failures.withValue { $0 += 1 }; failed.signal() })
            try check(try append(160, to: writer) == nil, "Append failed")
            let drain = LockedValue<Bool?>(nil); let drained = DispatchSemaphore(value: 0)
            writer.finish { value in drain.withValue { $0 = value }; drained.signal() }
            fake.failValidation(.configure(-1)); let notification = fake.notification; notification()
            try check(failed.wait(timeout: .now() + 2) == .success, "Failure was not reported")
            try check(drained.wait(timeout: .now() + 2) == .success && drain.withValue { $0 == false }, "Failed recovery falsely drained audio")
            notification(); _ = try append(0, to: writer)
            try check(failures.withValue { $0 } == 1 && fake.stops == 1, "Old failure callback repeated or engine leaked")
        }),
        ("cancelled buffer callbacks cannot complete a new voice session", {
            let fake = FakeLoopbackPlayback(); let writer = LoopbackWriter(playback: { fake })
            defer { writer.stop() }
            try configure(writer); writer.begin(); _ = try append(160, to: writer)
            let old = fake.takeConsumed()
            writer.cancel(); _ = try append(160, to: writer)
            let current = fake.takeConsumed(); let result = LockedValue<Bool?>(nil); let done = DispatchSemaphore(value: 0)
            writer.finish { value in result.withValue { $0 = value }; done.signal() }
            old.forEach { $0() }; _ = try append(0, to: writer)
            try check(result.withValue { $0 == nil }, "Old callbacks drained the new session")
            current.forEach { $0() }
            try check(done.wait(timeout: .now() + 2) == .success && result.withValue { $0 == true }, "Current playback did not drain")
        }),
        ("route validation does not bypass the two-second queue bound", {
            let fake = FakeLoopbackPlayback(); let writer = LoopbackWriter(playback: { fake })
            defer { writer.stop() }
            try configure(writer); _ = try append(32000, to: writer); try validate(fake)
            let failure = try append(1, to: writer)
            guard case .overflow? = failure else { throw Failure(message: "Recovery reset the pending audio limit") }
        }),
        ("consumed buffers return queue capacity after route validation", {
            let fake = FakeLoopbackPlayback(); let writer = LoopbackWriter(playback: { fake })
            defer { writer.stop() }
            try configure(writer); _ = try append(32000, to: writer); try validate(fake)
            fake.takeConsumed().forEach { $0() }
            try check(try append(160, to: writer) == nil, "Consumed audio remained counted after recovery")
        }),
        ("failed output configuration cannot later restart from its notification", {
            let fake = FakeLoopbackPlayback(); fake.failConfigure(.notReady)
            let writer = LoopbackWriter(playback: { fake }); defer { writer.stop() }
            let result: Result<Void, LoopbackFailure> = try waited { writer.configure(uid: "fixture-loopback", completion: $0) }
            guard case .failure = result else { throw Failure(message: "Failed configure accepted") }
            fake.notification(); _ = try append(0, to: writer)
            try check(fake.validations == 0 && fake.stops == 1, "Failed configuration came back to life")
        })
    ]
}
