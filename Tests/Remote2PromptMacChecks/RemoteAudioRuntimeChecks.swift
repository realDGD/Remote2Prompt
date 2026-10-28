import Foundation
import Remote2PromptCore
import Remote2PromptMac

private final class RuntimePlayback: LoopbackPlayback, @unchecked Sendable {
    private let lock = NSLock()
    private var configured = 0
    private var stopped = 0
    var configurations: Int { lock.withLock { configured } }
    var stops: Int { lock.withLock { stopped } }
    func configure(uid: String, configurationChanged: @escaping @Sendable () -> Void) throws(LoopbackFailure) {
        lock.withLock { configured += 1 }
    }
    func begin() {}
    func append(_ samples: [Int16], consumed: @escaping @Sendable () -> Void) throws(LoopbackFailure) { consumed() }
    func validateRoute() throws(LoopbackFailure) {}
    func finish(completion: @escaping @Sendable (Bool) -> Void) { completion(true) }
    func stop() { lock.withLock { stopped += 1 } }
}

@MainActor private final class RuntimeTransport: RemoteVoiceTransport {
    var onReady: ((VoiceCapabilities) -> Void)?
    var onStarted: (() -> Void)?
    var onStopped: ((RemoteVoiceStopReason) -> Void)?
    var onAudio: ((Data) -> Void)?
    var onSync: ((Data) -> Void)?
    var onStatus: ((String) -> Void)?
    var onFailure: ((String) -> Void)?
    var starts = 0, stops = 0, opens = 0, closes = 0
    var sendsStartedOnOpen = true
    var events: ((String) -> Void)?
    func start() {
        starts += 1
        onReady?(try! VoiceCapabilities(packet: Data([11, 1, 0, 2, 3, 0, 120])))
    }
    func stop() { stops += 1; events?("transport.stop") }
    func open() -> Bool { opens += 1; if sendsStartedOnOpen { onStarted?() }; return true }
    func close() -> Bool { closes += 1; return true }
}

@MainActor private final class VoiceSessionInputs: AudioInputSystem {
    var current: String? = "fixture-physical"
    var change: (@MainActor () -> Void)?
    var event: ((String) -> Void)?
    var delayRestoration = false
    private(set) var acceptedRestore: InputPriorityRequest?
    func start(onChange: @escaping @MainActor () -> Void) throws { change = onChange }
    func snapshot() throws -> SystemInputSnapshot {
        SystemInputSnapshot(inputs: [
            SystemAudioInput(policy: AudioInput(uid: "fixture-physical", isVirtual: false), name: "Physical"),
            SystemAudioInput(policy: AudioInput(uid: "fixture-loopback", isVirtual: true), name: "Virtual")
        ], defaultUID: current)
    }
    func setDefaultInput(_ request: InputPriorityRequest) throws {
        guard current == request.sourceUID else { throw InputSystemFailure.defaultChanged }
        if delayRestoration && request.purpose == .restore { acceptedRestore = request; return }
        apply(request)
    }
    func applyAcceptedRestore() {
        guard let request = acceptedRestore else { return }
        acceptedRestore = nil; apply(request)
    }
    private func apply(_ request: InputPriorityRequest) {
        current = request.targetUID
        event?(current == "fixture-physical" ? "input.restore" : "input.virtual")
        change?()
    }
    func stop() { change = nil }
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

@MainActor private final class VoiceInputHarness {
    let audio = AudioHarness()
    let system = VoiceSessionInputs()
    let input: AudioInputPriorityRuntime
    private var voice = VoiceSession()
    var downs = 0, ups = 0
    var heldTrigger: VoiceTrigger? { voice.heldTrigger }
    init() {
        input = AudioInputPriorityRuntime(system: system)
        var c = AppConfiguration(); c.voiceEnabled = true; c.remoteAudioEnabled = true
        c.preferVirtualInput = true; c.selectedVirtualInputUID = "fixture-loopback"
        input.configure(c)
        system.event = { [weak self] in self?.audio.events.append($0) }
        audio.runtime.prepareInput = { [weak self] completion in self?.input.beginVoiceSession(completion: completion) }
        audio.runtime.onBegin = { [weak self] in
            guard let self else { return false }
            let events = voice.begin(owner: "fixture-audio", trigger: .rightControl)
            downs += events.filter(\.isDown).count
            audio.events.append("key.down")
            return events.count == 1
        }
        audio.runtime.onEnd = { [weak self] in
            guard let self else { return }
            let events = voice.end(owner: "fixture-audio")
            ups += events.filter { !$0.isDown }.count
            if !events.isEmpty { audio.events.append("key.up") }
            input.endVoiceSession()
        }
        audio.enable(); input.setReady(true)
    }
    func shutdown() { audio.runtime.shutdown(); input.shutdownImmediately() }
}

@MainActor private func eventually(_ predicate: () -> Bool) async throws {
    let deadline = ProcessInfo.processInfo.systemUptime + 2
    while !predicate() && ProcessInfo.processInfo.systemUptime < deadline { try await Task.sleep(for: .milliseconds(2)) }
    try check(predicate(), "Runtime did not reach the expected state")
}

@MainActor func remoteAudioRuntimeChecks() -> [(String, @MainActor () async throws -> Void)] {
    [
        ("audio repress waits through an accepted restore before the next key down", {
            let h = VoiceInputHarness(); defer { h.shutdown() }
            try await eventually { h.audio.runtime.isReady }
            try check(h.audio.runtime.press() && h.downs == 1, "Initial press failed")
            h.audio.runtime.release(); h.system.delayRestoration = true; h.audio.events.removeAll()
            try check(h.audio.runtime.press(), "Repress was rejected")
            try check(h.ups == 1 && h.downs == 1 && h.audio.transport.opens == 1 && h.system.acceptedRestore != nil, "New key preceded old restore confirmation")
            h.audio.transport.onStopped?(.ordinaryReported)
            try check(h.audio.runtime.sessionActive && h.downs == 1, "Host close ACK cancelled the preparing replacement")
            h.system.delayRestoration = false; h.system.applyAcceptedRestore()
            try await eventually { h.downs == 2 }
            try check(Array(h.audio.events.prefix(4)) == ["key.up", "input.restore", "input.virtual", "key.down"], "Repress key/input order changed")
            try check(h.audio.transport.opens == 2 && h.heldTrigger == .rightControl, "Replacement did not start exactly once")
            h.audio.runtime.release(); try await eventually { !h.audio.runtime.sessionActive }
            try check(h.downs == 2 && h.ups == 2 && h.heldTrigger == nil && h.system.current == "fixture-physical", "Final release stuck a key or lost the original input")
        }),
        ("sleep while repress waits cannot send a late replacement key", {
            let h = VoiceInputHarness(); defer { h.shutdown() }
            try await eventually { h.audio.runtime.isReady }; try check(h.audio.runtime.press(), "Initial press failed")
            h.audio.runtime.release(); h.system.delayRestoration = true
            try check(h.audio.runtime.press() && h.system.acceptedRestore != nil, "No delayed restore to test")
            h.audio.runtime.suspend(); h.system.delayRestoration = false; h.system.applyAcceptedRestore()
            h.input.refreshInputs(); try await Task.sleep(for: .milliseconds(20))
            try check(h.downs == 1 && h.ups == 1 && h.heldTrigger == nil && h.audio.transport.opens == 1, "Late preparation sent a key after sleep")
            try check(h.system.current == "fixture-physical" && !h.audio.runtime.sessionActive, "Cancelled repress lost restoration")
        }),
        ("voice limit origin requires actual START and reported stop stays neutral", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }; h.transport.sendsStartedOnOpen = false
            try check(h.runtime.press(), "Press failed")
            try check(h.runtime.voiceLimit.segmentID == nil, "HID press invented START")
            h.transport.onAudio?(Data(repeating: 0, count: 120))
            try check(h.runtime.voiceLimit.segmentID == nil, "Audio packet invented START")
            h.now = 2; h.transport.onStarted?(); h.now = 20; h.transport.onStarted?()
            try check(h.runtime.voiceLimit.presentation(at: 52) == .countdown(seconds: 10, urgent: false), "Duplicate START rebased origin")
            h.now = 62; h.transport.onStopped?(.timeLimitReported)
            try check(h.runtime.voiceLimit.presentation(at: 62) == .endedUnconfirmed, "Reported reason became confirmed timeout or release erased it")
            h.runtime.release()
            try check(h.runtime.voiceLimit.presentation(at: 64) == .endedUnconfirmed, "Duplicate release erased end hint")
            h.transport.sendsStartedOnOpen = true; h.now = 63
            try check(h.runtime.press(), "Repress failed")
            try check(h.runtime.voiceLimit.presentation(at: 113) == .countdown(seconds: 10, urgent: false), "New segment lost its own clock")
            h.runtime.release(); h.transport.onStopped?(.timeLimitReported)
            try check(h.runtime.voiceLimit.presentation(at: 113) == .hidden, "Host close acknowledgement created timeout hint")
        }),
        ("failure and old transport START cannot revive a cancelled voice limit", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }; try check(h.runtime.press(), "Press failed")
            let oldStart = h.transport.onStarted; let oldStop = h.transport.onStopped
            h.transport.onFailure?("fixture loss"); h.advance(1)
            try await eventually { h.runtime.isReady }; h.now = 10
            try check(h.runtime.press(), "New press failed")
            oldStart?(); oldStop?(.timeLimitReported)
            try check(h.runtime.voiceLimit.presentation(at: 60) == .countdown(seconds: 10, urgent: false), "Old connection modified new segment")
            h.runtime.suspend()
            try check(h.runtime.voiceLimit.presentation(at: 60) == .hidden, "Sleep retained reminder")
        }),
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
        ("rapid repress pairs every trigger and the final release drains exactly once", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }
            for _ in 0..<100 {
                try check(h.runtime.press(), "Rapid voice press failed")
                h.transport.onAudio?(Data(repeating: 0, count: 120))
                h.runtime.release()
            }
            try await eventually { !h.runtime.sessionActive }
            try check(h.begins == 100 && h.ends == 100 && h.transport.opens == 100, "Rapid re-press lost a paired release")
        }),
        ("audio failure and sleep restore input after releasing the trigger through the real input runtime", {
            let h = AudioHarness(); let system = VoiceSessionInputs()
            let input = AudioInputPriorityRuntime(system: system)
            defer { h.runtime.shutdown(); input.shutdownImmediately() }
            var config = AppConfiguration(); config.voiceEnabled = true; config.remoteAudioEnabled = true
            config.preferVirtualInput = true; config.selectedVirtualInputUID = "fixture-loopback"
            input.configure(config)
            system.event = { [weak h] in h?.events.append($0) }
            h.runtime.prepareInput = { input.beginVoiceSession(completion: $0) }
            h.runtime.onEnd = { [weak h] in h?.ends += 1; h?.events.append("key.up"); input.endVoiceSession() }
            h.enable(); try await eventually { h.runtime.isReady }; input.setReady(true)
            try check(h.runtime.press(), "Voice did not prepare")
            input.refreshInputs(); try await eventually { h.begins == 1 }
            try check(system.current == "fixture-loopback", "Trigger preceded confirmed virtual input")
            h.events.removeAll(); h.transport.onFailure?("fixture link failure")
            input.refreshInputs(); try await eventually { system.current == "fixture-physical" }
            try check(h.events.first == "key.up" && h.events.contains("input.restore"), "Failure restored input before key release")
            h.advance(1); try await eventually { h.runtime.isReady }; input.setReady(true)
            try check(system.current == "fixture-physical" && !h.runtime.sessionActive, "Recovery took input while idle")
            try check(h.runtime.press(), "Voice did not prepare after recovery")
            input.refreshInputs(); try await eventually { h.begins == 2 }
            h.events.removeAll(); h.runtime.suspend()
            input.refreshInputs(); try await eventually { system.current == "fixture-physical" }
            try check(h.events.first == "key.up" && h.events.contains("input.restore"), "Sleep restored input before key release")
        }),
        ("suspend releases voice resources and ignores polling, retry and old callbacks", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }; try check(h.runtime.press(), "Voice did not begin")
            let oldReady = h.transport.onReady; let oldStarted = h.transport.onStarted
            h.events.removeAll(); h.runtime.suspend(); h.runtime.suspend()
            try check(!h.runtime.isReady && !h.runtime.sessionActive && h.ends == 1 && h.events.first == "end", "Suspend did not release voice before teardown")
            h.advance(100); h.runtime.retry(); h.runtime.setRemoteCount(0)
            oldReady?(try VoiceCapabilities(packet: Data([11, 1, 0, 2, 3, 0, 120]))); oldStarted?()
            try check(h.transport.starts == 1 && h.transport.opens == 1 && !h.runtime.isReady, "Sleeping audio was revived")
            h.runtime.resume(); h.runtime.resume();
            try check(h.transport.starts == 1, "Wake trusted a stale HID count")
            h.runtime.setRemoteCount(1); try await eventually { h.runtime.isReady }
            try check(h.transport.starts == 2 && !h.runtime.sessionActive && h.begins == 1, "Wake reopened a voice or duplicated connection")
            try check(h.runtime.press() && h.begins == 2, "Fresh press after wake failed")
        }),
        ("sleep during recovery or configuration cannot complete an old connection", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            h.runtime.suspend(); h.advance(100)
            try await Task.sleep(for: .milliseconds(20))
            try check(!h.runtime.isReady && h.transport.starts == 0, "Late configuration connected during sleep")
            h.runtime.resume(); h.runtime.setRemoteCount(1); try await eventually { h.runtime.isReady }
            h.transport.onFailure?("fixture recovery"); h.runtime.suspend(); h.advance(100)
            try check(h.transport.starts == 1, "Scheduled recovery ran while suspended")
            h.runtime.resume(); h.runtime.setRemoteCount(1); try await eventually { h.runtime.isReady }
            h.runtime.suspend(); h.runtime.shutdown(); h.runtime.resume(); h.advance(100)
            try check(!h.runtime.isReady && h.transport.starts == 2, "Wake revived shutdown resources")
        }),
        ("configuration changes during sleep are kept without opening resources", {
            let h = AudioHarness(); defer { h.runtime.shutdown() }; h.enable()
            try await eventually { h.runtime.isReady }; h.runtime.suspend()
            var disabled = AppConfiguration(); disabled.selectedVirtualInputUID = "fixture-loopback"
            h.runtime.configure(disabled); h.advance(100); h.runtime.resume()
            try check(!h.runtime.isReady && h.transport.starts == 1 && h.transport.opens == 0, "Sleeping opt-out opened resources")
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
