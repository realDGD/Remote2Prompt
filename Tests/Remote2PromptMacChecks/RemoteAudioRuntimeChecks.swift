import Foundation
import Remote2PromptCore
import Remote2PromptMac

private final class RuntimePlayback: LoopbackPlayback, @unchecked Sendable {
    private let lock = NSLock()
    private var configured = 0
    private var stopped = 0
    private var held: [@Sendable () -> Void] = []
    var configurations: Int { lock.withLock { configured } }
    var stops: Int { lock.withLock { stopped } }
    func configure(uid: String, configurationChanged: @escaping @Sendable () -> Void) throws(LoopbackFailure) {
        lock.withLock { configured += 1 }
    }
    func begin() { lock.withLock { held.removeAll() } }
    func append(_ samples: [Int16], consumed: @escaping @Sendable () -> Void) throws(LoopbackFailure) { consumed() }
    func validateRoute() throws(LoopbackFailure) {}
    func finish(completion: @escaping @Sendable (Bool) -> Void) { completion(true) }
    func stop() { lock.withLock { stopped += 1; held.removeAll() } }
}

@MainActor private final class RuntimeTransport: RemoteVoiceTransport {
    var onReady: ((VoiceCapabilities) -> Void)?
    var onStarted: (() -> Void)?
    var onStopped: (() -> Void)?
    var onAudio: ((Data) -> Void)?
    var onSync: ((Data) -> Void)?
    var onStatus: ((String) -> Void)?
    var onFailure: ((String) -> Void)?
    var starts = 0, stops = 0, opens = 0, closes = 0
    var events: ((String) -> Void)?
    func start() {
        starts += 1
        onReady?(try! VoiceCapabilities(packet: Data([11, 1, 0, 2, 3, 0, 120])))
    }
    func stop() { stops += 1; events?("transport.stop") }
    func open() -> Bool { opens += 1; onStarted?(); return true }
    func close() -> Bool { closes += 1; return true }
}

@MainActor private final class AudioHarness {
    var now = 0.0
    var available = [LoopbackDevice(uid: "fixture-loopback", name: "Fixture loopback")]
    let playback = RuntimePlayback()
    let transport = RuntimeTransport()
    var runtime: RemoteAudioRuntime!
    var begins = 0, ends = 0
    var events: [String] = []
    init() {
        let playback = playback
        runtime = RemoteAudioRuntime(writer: LoopbackWriter(playback: { playback }), transport: transport,
                                     catalog: { [weak self] in self?.available ?? [] },
                                     clock: { [weak self] in self?.now ?? 0 }, automaticMonitoring: false)
        runtime.canStart = { true }
        runtime.onBegin = { [weak self] in self?.begins += 1; self?.events.append("begin"); return true }
        runtime.onEnd = { [weak self] in self?.ends += 1; self?.events.append("end") }
        transport.events = { [weak self] in self?.events.append($0) }
    }
    func enable() {
        var config = AppConfiguration(); config.voiceEnabled = true; config.remoteAudioEnabled = true
        config.selectedVirtualInputUID = "fixture-loopback"
        runtime.configure(config); runtime.setRemoteCount(1)
    }
    func advance(_ seconds: Double) { now += seconds; runtime.refreshDevices() }
}

@MainActor private func eventually(_ predicate: () -> Bool) async throws {
    let deadline = ProcessInfo.processInfo.systemUptime + 2
    while !predicate() && ProcessInfo.processInfo.systemUptime < deadline { try await Task.sleep(for: .milliseconds(2)) }
    try check(predicate(), "Runtime did not reach the expected state")
}

@MainActor func remoteAudioRuntimeChecks() -> [(String, @MainActor () async throws -> Void)] {
    [
        ("audio recovery ends the voice before teardown and never reopens it automatically", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }
            try check(h.runtime.press(), "Ready voice did not begin")
            let staleReady = h.transport.onReady; let staleAudio = h.transport.onAudio
            h.events.removeAll(); h.transport.onFailure?("fixture disconnection")
            try check(!h.runtime.sessionActive && !h.runtime.isReady && h.ends == 1, "Failure retained a voice")
            try check(h.events.first == "end" && h.events.contains("transport.stop"), "Teardown preceded trigger release")
            h.advance(1); try await eventually { h.runtime.isReady }
            staleReady?(try VoiceCapabilities(packet: Data([11, 1, 0, 2, 3, 0, 120])))
            staleAudio?(Data(repeating: 0, count: 120))
            try check(h.transport.opens == 1 && h.begins == 1 && !h.runtime.sessionActive && h.runtime.receivedSamples == 0, "Recovery reopened an old voice")
            try check(h.runtime.press() && h.transport.opens == 2, "A fresh press did not work after recovery")
        }),
        ("audio recovery is bounded across successful but flapping connections", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }
            for delay in [1.0, 2.0, 4.0] {
                h.transport.onFailure?("fixture flap"); h.advance(delay - 0.1)
                try check(!h.runtime.isReady, "Recovery skipped backoff")
                h.advance(0.1); try await eventually { h.runtime.isReady }
            }
            h.transport.onFailure?("fixture flap"); h.advance(100)
            try check(!h.runtime.isReady && h.transport.starts == 4 && h.runtime.status.contains("3次"), "Flapping reset the finite budget")
            h.runtime.retry(); try await eventually { h.runtime.isReady }
            try check(h.transport.starts == 5 && !h.runtime.sessionActive, "Explicit retry did not reset the budget")
        }),
        ("a healthy interval replenishes recovery while idle health never opens the microphone", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }
            for delay in [1.0, 2.0, 4.0] {
                h.transport.onFailure?("fixture flap"); h.advance(delay)
                try await eventually { h.runtime.isReady }
            }
            h.runtime.refreshDevices(); try await Task.sleep(for: .milliseconds(20))
            h.advance(10); try await Task.sleep(for: .milliseconds(20))
            h.transport.onFailure?("fixture after healthy interval"); h.advance(1)
            try await eventually { h.runtime.isReady }
            try check(h.transport.opens == 0 && h.begins == 0, "Idle maintenance opened a microphone")
        }),
        ("audio packet loss ends a held voice while silent packets keep it alive", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }; try check(h.runtime.press(), "Voice did not begin")
            for _ in 0..<20 {
                h.transport.onAudio?(Data(repeating: 0, count: 120)); h.advance(1)
                try check(h.runtime.sessionActive, "Silence was mistaken for packet loss")
                try await Task.sleep(for: .milliseconds(2))
            }
            h.advance(3)
            try check(!h.runtime.sessionActive && h.ends == 1 && h.runtime.status.contains("数据已中断"), "Midstream loss kept a silent held session")
        }),
        ("device removal cancels a voice and return only restores readiness", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }; try check(h.runtime.press(), "Voice did not begin")
            let oldFailure = h.transport.onFailure
            h.available = []; h.runtime.refreshDevices()
            try check(!h.runtime.isReady && !h.runtime.sessionActive && h.ends == 1, "Device removal retained the voice")
            h.available = [LoopbackDevice(uid: "fixture-loopback", name: "Fixture loopback")]
            h.runtime.refreshDevices(); try await eventually { h.runtime.isReady }
            oldFailure?("stale failure")
            try check(h.runtime.isReady && h.transport.opens == 1, "Old connection callback invalidated replacement")
        }),
        ("disabled and shutdown runtimes ignore retries and late transport events", {
            let h = AudioHarness(); h.runtime.setRemoteCount(1); h.runtime.refreshDevices()
            try check(h.transport.starts == 0 && h.playback.configurations == 0, "Defaults opened audio")
            h.enable(); try await eventually { h.runtime.isReady }
            let oldReady = h.transport.onReady
            h.runtime.shutdown(); h.runtime.retry(); h.advance(100)
            oldReady?(try VoiceCapabilities(packet: Data([11, 1, 0, 2, 3, 0, 120])))
            try check(!h.runtime.isReady && !h.runtime.sessionActive && h.transport.starts == 1, "Shutdown was revived")
        })
    ]
}
