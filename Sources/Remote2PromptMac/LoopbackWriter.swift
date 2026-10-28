import AudioToolbox
import Foundation

public enum LoopbackFailure: Error, LocalizedError, Sendable {
    case unavailable, configure(Int32), overflow, notReady
    public var errorDescription: String? {
        switch self {
        case .unavailable: "所选回环设备不可用，请检查 MiRemoteV 2ch 或 BlackHole 2ch。"
        case .configure(let code): "无法打开所选回环设备（\(code)）。"
        case .overflow: "音频队列已满，语音会话已停止。请重新连接音频后重试。"
        case .notReady: "请先选择并连接回环设备。"
        }
    }
}

/// Synchronous operations belong to the writer queue; callbacks may arrive on any thread.
/// The injected implementation lets checks exercise the actual queue owner without opening devices.
public protocol LoopbackPlayback: AnyObject, Sendable {
    func configure(uid: String, configurationChanged: @escaping @Sendable () -> Void) throws(LoopbackFailure)
    func begin()
    func append(_ samples: [Int16], consumed: @escaping @Sendable () -> Void) throws(LoopbackFailure)
    func finish(completion: @escaping @Sendable (Bool) -> Void)
    func validateRoute() throws(LoopbackFailure)
    func stop()
}

/// All playback state belongs to this serial queue. No default input/output property is ever written.
public final class LoopbackWriter: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.remote2prompt.audio-output", qos: .userInitiated)
    private let makePlayback: @Sendable () -> any LoopbackPlayback
    private var playback: (any LoopbackPlayback)?
    private var pending = 0
    private var generation: UInt64 = 0
    private var routeGeneration: UInt64 = 0
    private var drained: (@Sendable (Bool) -> Void)?
    private var finishingPlayback = false
    private var recoveryFailure: (@Sendable (LoopbackFailure) -> Void)?

    public init() { makePlayback = { AudioQueueLoopbackPlayback() } }
    public init(playback: @escaping @Sendable () -> any LoopbackPlayback) { makePlayback = playback }

    public func configure(uid: String?, onFailure: (@Sendable (LoopbackFailure) -> Void)? = nil,
                          completion: @escaping @Sendable (Result<Void, LoopbackFailure>) -> Void) {
        queue.async { [self] in
            tearDown()
            guard let uid else { completion(.failure(.notReady)); return }
            let value = makePlayback()
            let token = routeGeneration
            do {
                try value.configure(uid: uid) { [weak self] in
                    // Device callbacks never synchronously stop/dispose their own playback resource.
                    self?.queue.async { [weak self] in self?.validate(route: token) }
                }
                playback = value; recoveryFailure = onFailure
                completion(.success(()))
            } catch { value.stop(); completion(.failure(playbackFailure(error))) }
        }
    }
    private func validate(route token: UInt64) {
        guard routeGeneration == token, let playback else { return }
        do { try playback.validateRoute() }
        catch {
            let failure = recoveryFailure
            tearDown()
            failure?(error)
        }
    }
    public func begin() {
        queue.async { [self] in
            generation &+= 1; drained?(false); drained = nil; pending = 0
            finishingPlayback = false
            playback?.begin()
        }
    }
    public func append(_ samples: [Int16], completion: @escaping @Sendable (LoopbackFailure?) -> Void) {
        queue.async { [self] in
            guard let playback else { completion(.notReady); return }
            guard pending + samples.count <= 32000 else { tearDown(); completion(.overflow); return }
            guard !samples.isEmpty else { completion(nil); return }
            let token = generation
            let sampleCount = samples.count
            pending += sampleCount
            do {
                try playback.append(samples) { [weak self] in
                    self?.queue.async { [weak self] in
                        guard let self, self.generation == token else { return }
                        self.pending = max(0, self.pending - sampleCount)
                        self.finishIfConsumed()
                    }
                }
                completion(nil)
            } catch { tearDown(); completion(playbackFailure(error)) }
        }
    }
    public func finish(completion: @escaping @Sendable (Bool) -> Void) {
        queue.async { [self] in
            guard playback != nil else { completion(false); return }
            drained?(false); drained = completion
            let token = generation
            finishIfConsumed()
            queue.asyncAfter(deadline: .now() + 1) { [self] in
                guard generation == token, let done = drained else { return }
                drained = nil; finishingPlayback = false; generation &+= 1; pending = 0
                playback?.begin(); done(false)
            }
        }
    }
    private func finishIfConsumed() {
        guard pending == 0, drained != nil, !finishingPlayback, let playback else { return }
        finishingPlayback = true
        let token = generation
        playback.finish { [weak self] completed in
            self?.queue.async { [weak self] in
                guard let self, self.generation == token, let done = self.drained else { return }
                self.drained = nil; self.finishingPlayback = false
                self.generation &+= 1; self.pending = 0
                done(completed)
            }
        }
    }
    public func cancel() { begin() }
    public func stop(completion: (@Sendable () -> Void)? = nil) { queue.async { [self] in tearDown(); completion?() } }
    private func tearDown() {
        routeGeneration &+= 1; generation &+= 1; pending = 0
        let done = drained; drained = nil; finishingPlayback = false; recoveryFailure = nil
        playback?.stop(); playback = nil
        done?(false)
    }
}

private func playbackFailure(_ error: any Error) -> LoopbackFailure {
    (error as? LoopbackFailure) ?? .configure(Int32(clamping: (error as NSError).code))
}
