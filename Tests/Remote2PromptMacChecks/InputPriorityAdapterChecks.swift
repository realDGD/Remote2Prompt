import CoreAudio
import Remote2PromptCore
import Remote2PromptMac

@MainActor
private final class InputClock { var now: Double = 0 }

@MainActor
private final class FakeAudioInputs: AudioInputSystem {
    enum Mode { case immediate, delayed, ignored, denied }
    var mode = Mode.immediate
    var snapshotFails = false
    var startFails = false
    var raceBeforeWrite = false
    var current: String? = "built-in"
    var inputs = [
        SystemAudioInput(policy: AudioInput(uid: "built-in", isVirtual: false), name: "Built-in"),
        SystemAudioInput(policy: AudioInput(uid: "airpods", isVirtual: false), name: "AirPods"),
        SystemAudioInput(policy: AudioInput(uid: "virtual", isVirtual: true), name: "Loopback")
    ]
    var callback: (@MainActor () -> Void)?
    var listening = false
    var reads = 0
    var writes: [InputPriorityRequest] = []
    var pendingUID: String?
    func start(onChange: @escaping @MainActor () -> Void) throws {
        listening = true; callback = onChange
        if startFails { throw InputSystemFailure.property(-1) }
    }
    func snapshot() throws -> SystemInputSnapshot {
        reads += 1
        if snapshotFails { throw InputSystemFailure.property(-1) }
        return SystemInputSnapshot(inputs: inputs, defaultUID: current)
    }
    func setDefaultInput(_ request: InputPriorityRequest) throws {
        if raceBeforeWrite { current = "airpods"; raceBeforeWrite = false }
        guard current == request.sourceUID else { throw InputSystemFailure.defaultChanged }
        writes.append(request)
        switch mode {
        case .immediate: current = request.targetUID; callback?()
        case .delayed: pendingUID = request.targetUID
        case .ignored: break
        case .denied: throw InputSystemFailure.notSettable
        }
    }
    func applyPending() { current = pendingUID; pendingUID = nil; callback?() }
    func stop() { listening = false; callback = nil }
}

@MainActor
private func fixture(mode: FakeAudioInputs.Mode = .immediate, enabled: Bool = true) -> (FakeAudioInputs, InputPriorityCoordinator, InputClock) {
    let system = FakeAudioInputs(); system.mode = mode
    let clock = InputClock()
    let coordinator = InputPriorityCoordinator(system: system, clock: { clock.now })
    coordinator.start()
    coordinator.configure(enabled: enabled, selectedUID: "virtual", readyRemotes: ["ready-a"])
    return (system, coordinator, clock)
}

@MainActor
func inputPriorityAdapterChecks() -> [(String, @MainActor () throws -> Void)] {
    var cases = inputSwitchChecks()
    cases.append(contentsOf: inputFailureChecks())
    cases.append(contentsOf: inputLifecycleChecks())
    return cases
}

@MainActor
private func inputSwitchChecks() -> [(String, @MainActor () throws -> Void)] {
    [
        ("disabled input priority only observes the system", {
            let (system, coordinator, _) = fixture(enabled: false)
            for _ in 0..<100 { system.callback?() }
            try check(system.writes.isEmpty && coordinator.state.observedInput == "Built-in", "Disabled controller changed input")
            coordinator.stop()
        }),
        ("priority confirms readback and restores latest physical preemption", {
            let (system, coordinator, clock) = fixture()
            try check(system.current == "virtual" && coordinator.state.ownsInput && coordinator.state.confirmedInput == "Loopback", "Initial confirmed ownership missing")
            clock.now = 0.5; system.current = "airpods"; system.callback?()
            try check(system.current == "virtual" && coordinator.state.restoreInput == "AirPods", "Physical preemption was not remembered")
            clock.now = 1
            coordinator.configure(enabled: true, selectedUID: "virtual", readyRemotes: [])
            try check(system.current == "airpods" && !coordinator.state.ownsInput, "Last-ready disconnect did not restore")
            coordinator.stop()
        }),
        ("own input notifications do not cause duplicate writes", {
            let (system, coordinator, clock) = fixture()
            for index in 1...100 { clock.now = Double(index); system.callback?() }
            try check(system.writes.count == 1, "Own notification caused a write loop")
            coordinator.stop()
        }),
        ("priority limits rapid external preemption globally", {
            let (system, coordinator, clock) = fixture()
            system.current = "airpods"
            for _ in 0..<100 { system.callback?() }
            try check(system.writes.count == 1 && coordinator.nextWakeup == 0.5, "Notification storm bypassed minimum write spacing")
            clock.now = 0.5; coordinator.refresh()
            try check(system.writes.count == 2 && system.current == "virtual", "Coalesced preemption did not recover")
            coordinator.stop()
        }),
        ("one remaining ready source keeps virtual input", {
            let (system, coordinator, clock) = fixture()
            coordinator.configure(enabled: true, selectedUID: "virtual", readyRemotes: ["ready-a", "ready-b"])
            coordinator.configure(enabled: true, selectedUID: "virtual", readyRemotes: ["ready-b"])
            try check(system.writes.count == 1 && system.current == "virtual", "One disconnect restored too early")
            clock.now = 0.5; coordinator.configure(enabled: true, selectedUID: "virtual", readyRemotes: [])
            try check(system.current == "built-in", "Final source did not restore")
            coordinator.stop()
        })
    ]
}

@MainActor
private func inputFailureChecks() -> [(String, @MainActor () throws -> Void)] {
    [
        ("accepted but ignored input writes pause after three attempts", {
            let (system, coordinator, clock) = fixture(mode: .ignored)
            try check(!coordinator.state.ownsInput && coordinator.state.pending, "noErr was treated as confirmed input")
            for tick in 1...60 { clock.now = Double(tick) * 0.1; coordinator.refresh() }
            try check(system.writes.count == 3 && coordinator.state.phase == .paused && !coordinator.state.ownsInput, "Ignored writes did not stop at three")
            coordinator.stop()
        }),
        ("denied input writes remain bounded under notification storms", {
            let (system, coordinator, clock) = fixture(mode: .denied)
            for tick in 1...50 {
                clock.now = Double(tick) * 0.1
                for _ in 0..<10 { system.callback?() }
            }
            try check(system.writes.count == 3 && coordinator.state.phase == .paused, "Denied writes became an unbounded retry")
            system.mode = .immediate; coordinator.retry()
            try check(system.current == "virtual" && coordinator.state.ownsInput, "Explicit retry could not recover")
            coordinator.stop()
        }),
        ("delayed input readback is required before ownership", {
            let (system, coordinator, clock) = fixture(mode: .delayed)
            try check(!coordinator.state.ownsInput && coordinator.state.confirmedInput == nil, "Pending input was shown as confirmed")
            clock.now = 0.2; system.applyPending()
            try check(coordinator.state.ownsInput && coordinator.state.confirmedInput == "Loopback" && system.writes.count == 1, "Delayed readback was not confirmed exactly once")
            coordinator.stop()
        }),
        ("disable during pending input write restores after late confirmation", {
            let (system, coordinator, clock) = fixture(mode: .delayed)
            coordinator.configure(enabled: false, selectedUID: "virtual", readyRemotes: [])
            clock.now = 0.2; system.applyPending()
            try check(coordinator.state.ownsInput && system.writes.count == 1, "Old accepted write was discarded without restoration ownership")
            clock.now = 0.5; system.mode = .immediate; coordinator.refresh()
            try check(system.current == "built-in" && !coordinator.state.ownsInput && system.writes.count == 2, "Late input was not restored after disable")
            coordinator.stop()
        }),
        ("failed input reads cannot cause writes", {
            let (system, coordinator, clock) = fixture(enabled: false)
            system.snapshotFails = true
            coordinator.configure(enabled: true, selectedUID: "virtual", readyRemotes: ["ready-a"])
            try check(system.writes.isEmpty && coordinator.state.phase == .failed && coordinator.nextWakeup == 2, "Read failure invented a current input or busy retry")
            clock.now = 2; system.snapshotFails = false; coordinator.refresh()
            try check(system.current == "virtual", "Read recovery failed")
            coordinator.stop()
        }),
        ("source change immediately before input write preserves external choice", {
            let (system, coordinator, clock) = fixture(enabled: false)
            system.raceBeforeWrite = true
            coordinator.configure(enabled: true, selectedUID: "virtual", readyRemotes: ["ready-a"])
            coordinator.configure(enabled: false, selectedUID: "virtual", readyRemotes: [])
            clock.now = 1; coordinator.refresh()
            try check(system.current == "airpods" && system.writes.isEmpty && !coordinator.state.ownsInput, "Stale source overwrote external choice")
            coordinator.stop()
        })
    ]
}

@MainActor
private func inputLifecycleChecks() -> [(String, @MainActor () throws -> Void)] {
    [
        ("physical hot unplug uses stable eligible fallback", {
            let (system, coordinator, clock) = fixture()
            system.inputs.removeAll { $0.policy.uid == "built-in" }
            system.inputs.append(SystemAudioInput(policy: AudioInput(uid: "unknown", kind: .unknown), name: "Unknown"))
            clock.now = 0.5; coordinator.configure(enabled: false, selectedUID: nil, readyRemotes: [])
            try check(system.current == "airpods", "Unavailable original or unknown device was restored")
            coordinator.stop()
        }),
        ("initial virtual input remains a user choice after disable", {
            let system = FakeAudioInputs(); system.current = "virtual"
            let coordinator = InputPriorityCoordinator(system: system)
            coordinator.start(); coordinator.configure(enabled: true, selectedUID: "virtual", readyRemotes: ["ready-a"])
            coordinator.configure(enabled: false, selectedUID: nil, readyRemotes: [])
            try check(system.writes.isEmpty && !coordinator.state.ownsInput, "Existing virtual input was claimed")
            coordinator.stop()
        }),
        ("stopped input coordinator ignores queued callbacks", {
            let (system, coordinator, clock) = fixture()
            let stale = system.callback
            coordinator.stop(); let reads = system.reads
            clock.now = 5; system.current = "airpods"; stale?(); coordinator.retry(); coordinator.refresh()
            try check(!system.listening && system.reads == reads && system.writes.count == 1, "Teardown resurrected audio input resources")
        }),
        ("partial input listener start is cleaned up", {
            let system = FakeAudioInputs(); system.startFails = true
            let coordinator = InputPriorityCoordinator(system: system)
            coordinator.start(); coordinator.configure(enabled: true, selectedUID: "virtual", readyRemotes: ["ready-a"])
            try check(!system.listening && system.writes.isEmpty && coordinator.state.phase == .failed, "Partial listener startup remained active")
            system.startFails = false; coordinator.retry()
            try check(system.current == "virtual", "Listener startup could not retry")
            coordinator.stop()
        }),
        ("CoreAudio transport classification excludes virtual and unknown fallback", {
            try check(CoreAudioInputSystem.kind(transport: kAudioDeviceTransportTypeBuiltIn) == .physical, "Built-in was not physical")
            try check(CoreAudioInputSystem.kind(transport: kAudioDeviceTransportTypeUSB) == .physical, "USB was not physical")
            try check(CoreAudioInputSystem.kind(transport: kAudioDeviceTransportTypeBluetoothLE) == .physical, "Bluetooth LE was not physical")
            try check(CoreAudioInputSystem.kind(transport: kAudioDeviceTransportTypeAggregate) == .virtual, "Aggregate became physical")
            try check(CoreAudioInputSystem.kind(transport: kAudioDeviceTransportTypeVirtual) == .virtual, "Loopback became physical")
            try check(CoreAudioInputSystem.kind(transport: 0) == .unknown, "Unknown transport became physical")
        })
    ]
}
