import AppKit
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
    coordinator.configure(enabled: enabled, selectedUID: "virtual", activeVoices: ["ready-a"])
    return (system, coordinator, clock)
}

@MainActor
func inputPriorityAdapterChecks() -> [(String, @MainActor () throws -> Void)] {
    var cases = inputSwitchChecks()
    cases.append(contentsOf: inputFailureChecks())
    cases.append(contentsOf: inputLifecycleChecks())
    cases.append(contentsOf: voiceInputRuntimeChecks())
    cases.append(contentsOf: voiceInputRaceChecks())
    cases.append(contentsOf: voicePrerollChecks())
    cases.append(contentsOf: menuInputChecks())
    return cases
}

@MainActor
private func menuInputChecks() -> [(String, @MainActor () throws -> Void)] {
    func idle(_ mode: FakeAudioInputs.Mode = .immediate) -> (FakeAudioInputs, InputPriorityCoordinator, InputClock) {
        let system = FakeAudioInputs(); system.mode = mode
        let clock = InputClock()
        let coordinator = InputPriorityCoordinator(system: system, clock: { clock.now })
        coordinator.start()
        return (system, coordinator, clock)
    }
    return [
        ("menu input catalog follows system without writing", {
            let (system, coordinator, _) = idle()
            system.current = "airpods"; system.callback?()
            try check(coordinator.state.defaultUID == "airpods" && coordinator.state.inputs.count == 3 && system.writes.isEmpty, "Menu observation changed input or kept a stale catalog")
            coordinator.selectInput(uid: "airpods")
            try check(system.writes.isEmpty, "Selecting current input wrote unnecessarily")
            coordinator.stop()
        }),
        ("explicit menu choice is confirmed without voice ownership", {
            let (system, coordinator, _) = idle()
            coordinator.selectInput(uid: "airpods")
            try check(system.current == "airpods" && system.writes.count == 1 && system.writes[0].purpose == .userSelection, "Menu selection did not use explicit write")
            try check(coordinator.state.defaultUID == "airpods" && !coordinator.hasUnrestoredSession && !coordinator.state.selectingInput, "Menu choice took voice ownership or skipped readback")
            coordinator.stop()
        }),
        ("menu rejects a disconnected target and source race", {
            let (system, coordinator, _) = idle()
            coordinator.selectInput(uid: "missing")
            try check(system.writes.isEmpty && coordinator.state.selectionError != nil, "Stale target accepted")
            system.raceBeforeWrite = true
            coordinator.selectInput(uid: "virtual")
            try check(system.writes.isEmpty && system.current == "airpods" && coordinator.state.selectionError != nil, "Menu clobbered a concurrent system choice")
            coordinator.stop()
        }),
        ("delayed menu write requires readback and blocks another choice", {
            let (system, coordinator, _) = idle(.delayed)
            coordinator.selectInput(uid: "airpods")
            try check(coordinator.state.selectingInput && coordinator.state.defaultUID == "built-in" && !coordinator.canSelectInput, "Delayed write claimed success")
            coordinator.selectInput(uid: "virtual")
            try check(system.writes.count == 1, "A second choice raced pending input")
            system.applyPending()
            try check(!coordinator.state.selectingInput && coordinator.state.defaultUID == "airpods", "Delayed readback not reflected")
            coordinator.stop()
        }),
        ("ignored and rejected menu writes remain visible failures", {
            let (system, coordinator, clock) = idle(.ignored)
            coordinator.selectInput(uid: "airpods"); clock.now = 1; coordinator.refresh()
            try check(!coordinator.state.selectingInput && coordinator.state.selectionError != nil && system.current == "built-in", "Ignored write reported success")
            system.mode = .denied; coordinator.selectInput(uid: "airpods")
            try check(coordinator.state.selectionError != nil && !coordinator.hasUnrestoredSession, "Denied menu write created restore transaction")
            coordinator.stop()
        }),
        ("voice ownership and pending restoration block menu writes", {
            let (system, coordinator, _) = fixture()
            coordinator.selectInput(uid: "airpods")
            try check(system.writes.count == 1 && system.current == "virtual", "Menu interrupted held voice")
            system.mode = .delayed
            coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: [])
            coordinator.selectInput(uid: "airpods")
            try check(system.writes.count == 2 && !coordinator.canSelectInput, "Menu raced restore")
            system.applyPending()
            try check(coordinator.canSelectInput, "Menu stayed locked after restore")
            coordinator.stop()
        })
    ]
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
        ("voice input restores the pre-press input despite preemption", {
            let (system, coordinator, clock) = fixture()
            try check(system.current == "virtual" && coordinator.state.ownsInput && coordinator.state.confirmedInput == "Loopback", "Initial confirmed ownership missing")
            clock.now = 0.5; system.current = "airpods"; system.callback?()
            try check(system.current == "virtual" && coordinator.state.restoreInput == "Built-in", "Preemption replaced the press snapshot")
            clock.now = 1
            coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: [])
            try check(system.current == "built-in" && !coordinator.state.ownsInput, "Voice end did not restore the pre-press input")
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
            coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: ["ready-a", "ready-b"])
            coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: ["ready-b"])
            try check(system.writes.count == 1 && system.current == "virtual", "One disconnect restored too early")
            clock.now = 0.5; coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: [])
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
            coordinator.configure(enabled: false, selectedUID: "virtual", activeVoices: [])
            clock.now = 0.2; system.applyPending()
            try check(coordinator.state.ownsInput && system.writes.count == 2 && system.writes.last?.purpose == .restore, "Late takeover did not immediately request restoration")
            clock.now = 0.3; system.applyPending()
            try check(system.current == "built-in" && !coordinator.state.ownsInput && system.writes.count == 2, "Late input was not restored after disable")
            coordinator.stop()
        }),
        ("failed input reads cannot cause writes", {
            let (system, coordinator, clock) = fixture(enabled: false)
            system.snapshotFails = true
            coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: ["ready-a"])
            try check(system.writes.isEmpty && coordinator.state.phase == .failed && coordinator.nextWakeup == 2, "Read failure invented a current input or busy retry")
            clock.now = 2; system.snapshotFails = false; coordinator.refresh()
            try check(system.current == "virtual", "Read recovery failed")
            coordinator.stop()
        }),
        ("source change immediately before input write preserves external choice", {
            let (system, coordinator, clock) = fixture(enabled: false)
            system.raceBeforeWrite = true
            coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: ["ready-a"])
            coordinator.configure(enabled: false, selectedUID: "virtual", activeVoices: [])
            clock.now = 1; coordinator.refresh()
            try check(system.current == "airpods" && system.writes.isEmpty && !coordinator.state.ownsInput, "Stale source overwrote external choice")
            coordinator.stop()
        })
    ]
}

@MainActor
private func inputLifecycleChecks() -> [(String, @MainActor () throws -> Void)] {
    [
        ("graceful priority shutdown drains delayed writes in the modal run loop", {
            let system = FakeAudioInputs(); system.mode = .delayed
            let runtime = AudioInputPriorityRuntime(system: system)
            defer { runtime.shutdownImmediately() }
            var configuration = AppConfiguration()
            configuration.preferVirtualInput = true; configuration.voiceEnabled = true
            configuration.remoteAudioEnabled = true; configuration.selectedVirtualInputUID = "virtual"
            runtime.configure(configuration); runtime.setReady(true)
            runtime.beginVoiceSession { _ in }
            var completed = false
            runtime.shutdown { completed = true }
            let delivery = Timer(timeInterval: 0.1, repeats: false) { _ in
                MainActor.assumeIsolated { system.mode = .immediate; system.applyPending() }
            }
            RunLoop.main.add(delivery, forMode: .modalPanel)
            defer { delivery.invalidate() }
            let limit = Date().addingTimeInterval(2)
            while !completed && Date() < limit { _ = RunLoop.main.run(mode: .modalPanel, before: Date().addingTimeInterval(0.02)) }
            try check(completed && system.current == "built-in" && !system.listening, "Modal shutdown did not confirm restoration and clean up")
        }),
        ("graceful shutdown reports failed restoration without endless retries", {
            let system = FakeAudioInputs()
            let runtime = AudioInputPriorityRuntime(system: system)
            defer { runtime.shutdownImmediately() }
            var configuration = AppConfiguration()
            configuration.preferVirtualInput = true; configuration.voiceEnabled = true
            configuration.remoteAudioEnabled = true; configuration.selectedVirtualInputUID = "virtual"
            runtime.configure(configuration); runtime.setReady(true)
            runtime.beginVoiceSession { _ in }
            system.mode = .denied
            var completed = false
            runtime.shutdown { completed = true }
            let limit = Date().addingTimeInterval(2.5)
            while !completed && Date() < limit { _ = RunLoop.main.run(mode: .modalPanel, before: Date().addingTimeInterval(0.02)) }
            try check(completed && system.current == "virtual" && system.writes.count == 4 && runtime.state.error != nil && !system.listening, "Failed restoration was hidden or retried without bound")
        }),
        ("hardware-disabled priority runtime never starts or writes", {
            let system = FakeAudioInputs()
            let runtime = AudioInputPriorityRuntime(hardwareEnabled: false, system: system)
            var configuration = AppConfiguration()
            configuration.preferVirtualInput = true; configuration.voiceEnabled = true
            configuration.remoteAudioEnabled = true; configuration.selectedVirtualInputUID = "virtual"
            runtime.configure(configuration); runtime.setReady(true); runtime.retry()
            var completed = false
            runtime.shutdown { completed = true }
            runtime.shutdownImmediately()
            try check(completed && system.reads == 0 && system.writes.isEmpty && !system.listening, "UI smoke accessed audio hardware")
        }),
        ("priority runtime requires explicit opt-in and actual audio readiness", {
            let system = FakeAudioInputs()
            let runtime = AudioInputPriorityRuntime(system: system)
            var configuration = AppConfiguration()
            configuration.preferVirtualInput = true; configuration.selectedVirtualInputUID = "virtual"
            runtime.configure(configuration); runtime.setReady(true)
            configuration.voiceEnabled = true; runtime.configure(configuration)
            try check(system.writes.isEmpty, "Trigger-only mode took over system input")
            configuration.remoteAudioEnabled = true; runtime.configure(configuration)
            try check(system.writes.isEmpty, "Readiness changed idle system input")
            var allowed = false
            runtime.beginVoiceSession { allowed = $0 }
            try check(allowed && system.current == "virtual" && system.writes.count == 1, "Press did not acquire the virtual input")
            runtime.endVoiceSession()
            try check(system.current == "built-in", "Release did not restore immediately")
            system.current = "airpods"
            runtime.shutdownImmediately()
            try check(system.current == "airpods" && !system.listening, "Shutdown overwrote a later external choice")
        }),
        ("physical hot unplug uses stable eligible fallback", {
            let (system, coordinator, clock) = fixture()
            system.inputs.removeAll { $0.policy.uid == "built-in" }
            system.inputs.append(SystemAudioInput(policy: AudioInput(uid: "unknown", kind: .unknown), name: "Unknown"))
            clock.now = 0.5; coordinator.configure(enabled: false, selectedUID: nil, activeVoices: [])
            try check(system.current == "airpods", "Unavailable original or unknown device was restored")
            coordinator.stop()
        }),
        ("initial virtual input remains a user choice after disable", {
            let system = FakeAudioInputs(); system.current = "virtual"
            let coordinator = InputPriorityCoordinator(system: system)
            coordinator.start(); coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: ["ready-a"])
            coordinator.configure(enabled: false, selectedUID: nil, activeVoices: [])
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
            coordinator.start(); coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: ["ready-a"])
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

@MainActor
private func voiceInputRuntimeChecks() -> [(String, @MainActor () throws -> Void)] {
    [
        ("idle readiness never writes and press captures the latest default", {
            let system = FakeAudioInputs()
            let runtime = AudioInputPriorityRuntime(system: system)
            defer { runtime.shutdownImmediately() }
            var config = AppConfiguration()
            config.preferVirtualInput = true; config.voiceEnabled = true
            config.remoteAudioEnabled = true; config.selectedVirtualInputUID = "virtual"
            runtime.configure(config); runtime.setReady(true)
            system.current = "airpods"; system.callback?()
            try check(system.writes.isEmpty, "Idle default change was intercepted")
            var allowed = false
            runtime.beginVoiceSession { allowed = $0 }
            try check(allowed && runtime.state.restoreInput == "AirPods" && system.current == "virtual", "Press snapshot did not use the latest input")
            runtime.endVoiceSession()
            try check(system.current == "airpods", "Release did not return to the press snapshot")
            system.current = "built-in"; system.callback?()
            try check(system.writes.count == 2 && system.current == "built-in", "A post-release system change was overridden")
        }),
        ("trigger permission waits for delayed input confirmation", {
            let system = FakeAudioInputs(); system.mode = .delayed
            let runtime = AudioInputPriorityRuntime(system: system)
            defer { runtime.shutdownImmediately() }
            var config = AppConfiguration()
            config.preferVirtualInput = true; config.voiceEnabled = true
            config.remoteAudioEnabled = true; config.selectedVirtualInputUID = "virtual"
            runtime.configure(config); runtime.setReady(true)
            var results: [Bool] = []
            runtime.beginVoiceSession { results.append($0) }
            try check(results.isEmpty && system.current == "built-in", "Trigger started before input confirmation")
            system.applyPending()
            try check(results == [true] && runtime.state.readyForVoice, "Confirmed input did not release the trigger gate")
            runtime.endVoiceSession(); system.applyPending()
            try check(system.current == "built-in" && results == [true], "Restoration duplicated the begin callback")
        }),
        ("release before input confirmation cancels trigger and restores a late switch", {
            let system = FakeAudioInputs(); system.mode = .delayed
            let runtime = AudioInputPriorityRuntime(system: system)
            defer { runtime.shutdownImmediately() }
            var config = AppConfiguration()
            config.preferVirtualInput = true; config.voiceEnabled = true
            config.remoteAudioEnabled = true; config.selectedVirtualInputUID = "virtual"
            runtime.configure(config); runtime.setReady(true)
            var results: [Bool] = []
            runtime.beginVoiceSession { results.append($0) }
            runtime.endVoiceSession()
            try check(results == [false], "Cancelled begin was left pending")
            system.mode = .immediate; system.applyPending()
            try check(system.current == "built-in" && results == [false], "Late confirmation started a released voice session")
        }),
        ("voice opt-out permits the trigger without a default input write", {
            let system = FakeAudioInputs()
            let runtime = AudioInputPriorityRuntime(system: system)
            defer { runtime.shutdownImmediately() }
            var allowed = false
            runtime.beginVoiceSession { allowed = $0 }
            runtime.endVoiceSession()
            try check(allowed && system.writes.isEmpty, "Opt-out changed the default or blocked an ordinary voice trigger")
        }),
        ("input readiness loss cancels a pending trigger", {
            let system = FakeAudioInputs(); system.mode = .delayed
            let runtime = AudioInputPriorityRuntime(system: system)
            defer { runtime.shutdownImmediately() }
            var config = AppConfiguration()
            config.preferVirtualInput = true; config.voiceEnabled = true
            config.remoteAudioEnabled = true; config.selectedVirtualInputUID = "virtual"
            runtime.configure(config); runtime.setReady(true)
            var results: [Bool] = []
            runtime.beginVoiceSession { results.append($0) }
            runtime.setReady(false)
            try check(results == [false], "An unavailable audio path still allowed the trigger")
            system.mode = .immediate; system.applyPending()
            runtime.endVoiceSession()
            try check(system.current == "built-in" && results == [false], "Readiness failure lost the original input")
        }),
        ("failed voice preparation cannot take over later without another press", {
            let system = FakeAudioInputs()
            system.inputs.removeAll { $0.policy.uid == "virtual" }
            let runtime = AudioInputPriorityRuntime(system: system)
            defer { runtime.shutdownImmediately() }
            var config = AppConfiguration()
            config.preferVirtualInput = true; config.voiceEnabled = true
            config.remoteAudioEnabled = true; config.selectedVirtualInputUID = "virtual"
            runtime.configure(config); runtime.setReady(true)
            var results: [Bool] = []
            runtime.beginVoiceSession { results.append($0) }
            try check(results == [false], "Missing loopback did not cancel preparation")
            system.inputs.append(SystemAudioInput(policy: AudioInput(uid: "virtual", isVirtual: true), name: "Loopback"))
            system.callback?()
            try check(system.writes.isEmpty && results == [false], "A failed press turned into a later background takeover")
        }),
        ("shutdown reports an unavailable restore target instead of success", {
            let system = FakeAudioInputs()
            let runtime = AudioInputPriorityRuntime(system: system)
            var config = AppConfiguration()
            config.preferVirtualInput = true; config.voiceEnabled = true
            config.remoteAudioEnabled = true; config.selectedVirtualInputUID = "virtual"
            runtime.configure(config); runtime.setReady(true)
            runtime.beginVoiceSession { _ in }
            system.inputs.removeAll { $0.policy.isPhysical }
            runtime.endVoiceSession()
            var completed = false
            runtime.shutdown { completed = true }
            try check(completed && system.current == "virtual" && runtime.state.error != nil && !system.listening, "Missing return device was reported as a successful restore")
        }),
        ("late takeover restores a system choice made after release", {
            let (system, coordinator, clock) = fixture(mode: .delayed)
            coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: [])
            system.current = "airpods"; system.callback?()
            system.mode = .immediate; clock.now = 0.1; system.applyPending()
            try check(system.current == "airpods" && system.writes.count == 2, "A late takeover erased a post-release choice")
            coordinator.stop()
        }),
        ("late restoration does not permanently replace an idle system choice", {
            let (system, coordinator, _) = fixture()
            system.mode = .delayed
            coordinator.configure(enabled: true, selectedUID: "virtual", activeVoices: [])
            system.current = "airpods"; system.callback?()
            system.mode = .immediate; system.applyPending()
            try check(system.current == "airpods" && system.writes.count == 3 && !coordinator.state.ownsInput, "A delayed restore overrode the newer system choice")
            coordinator.stop()
        }),
        ("an unreadable press snapshot cannot be replaced by a later system state", {
            let system = FakeAudioInputs()
            let runtime = AudioInputPriorityRuntime(system: system)
            defer { runtime.shutdownImmediately() }
            var config = AppConfiguration()
            config.preferVirtualInput = true; config.voiceEnabled = true
            config.remoteAudioEnabled = true; config.selectedVirtualInputUID = "virtual"
            runtime.configure(config); runtime.setReady(true)
            system.snapshotFails = true
            var results: [Bool] = []
            runtime.beginVoiceSession { results.append($0) }
            try check(results == [false], "Missing press snapshot did not cancel preparation")
            system.snapshotFails = false; system.current = "airpods"; system.callback?()
            try check(system.writes.isEmpty && system.current == "airpods", "A later snapshot silently started the failed press")
        })
    ]
}

@MainActor
private func voicePrerollChecks() -> [(String, @MainActor () throws -> Void)] {
    [
        ("waiting for input preserves the first PCM samples in order", {
            var buffer = VoiceStartBuffer()
            try buffer.append([1, -2, 3]); try buffer.append([4, 5])
            try check(buffer.take() == [1, -2, 3, 4, 5] && buffer.take().isEmpty, "Preroll lost, reordered or duplicated the first audio")
        }),
        ("cancelled voice preroll cannot enter the next session", {
            var buffer = VoiceStartBuffer()
            try buffer.append([1, 2]); buffer.clear(); try buffer.append([3])
            try check(buffer.take() == [3], "Cancelled audio leaked into the next voice session")
        }),
        ("waiting voice audio is bounded and never silently drops the first samples", {
            var buffer = VoiceStartBuffer()
            try buffer.append([Int16](repeating: 7, count: 32000))
            do { try buffer.append([8]); throw Failure(message: "Unbounded preroll accepted") }
            catch LoopbackFailure.overflow {}
            try check(buffer.take().count == 32000, "Overflow silently truncated the existing preroll")
        })
    ]
}

@MainActor
private func voiceInputRaceChecks() -> [(String, @MainActor () throws -> Void)] {
    func makeRuntime(_ mode: FakeAudioInputs.Mode) -> (FakeAudioInputs, AudioInputPriorityRuntime, AppConfiguration) {
        let system = FakeAudioInputs(); system.mode = mode
        let runtime = AudioInputPriorityRuntime(system: system)
        var configuration = AppConfiguration()
        configuration.preferVirtualInput = true; configuration.voiceEnabled = true
        configuration.remoteAudioEnabled = true; configuration.selectedVirtualInputUID = "virtual"
        runtime.configure(configuration); runtime.setReady(true)
        return (system, runtime, configuration)
    }
    return [
        ("rapid re-press waits for the previous takeover without replacing the original input", {
            let (system, runtime, _) = makeRuntime(.delayed)
            defer { runtime.shutdownImmediately() }
            var first: [Bool] = []; var second: [Bool] = []
            runtime.beginVoiceSession { first.append($0) }; runtime.endVoiceSession()
            runtime.beginVoiceSession { second.append($0) }
            try check(first == [false] && second.isEmpty && system.writes.count == 1, "Re-press bypassed pending confirmation")
            system.mode = .immediate; system.applyPending()
            try check(second == [true] && runtime.state.readyForVoice && system.current == "virtual", "Re-press was not confirmed")
            runtime.endVoiceSession()
            try check(system.current == "built-in" && system.writes.count == 2 && first == [false] && second == [true], "Temporary input became the new restoration baseline")
        }),
        ("re-press during delayed restoration reacquires virtual input and keeps the same return target", {
            let (system, runtime, _) = makeRuntime(.immediate)
            defer { runtime.shutdownImmediately() }
            runtime.beginVoiceSession { _ in }
            system.mode = .delayed; runtime.endVoiceSession()
            var second: [Bool] = []
            runtime.beginVoiceSession { second.append($0) }
            try check(second.isEmpty && runtime.state.pending, "Re-press ignored the accepted restore")
            system.mode = .immediate; system.applyPending()
            try check(second == [true] && system.current == "virtual", "Late restoration permanently interrupted a new press")
            runtime.endVoiceSession()
            try check(system.current == "built-in" && system.writes.count == 4, "Re-press returned to the wrong input")
        }),
        ("audio readiness recovery cannot reacquire input until another physical press", {
            let (system, runtime, _) = makeRuntime(.immediate)
            defer { runtime.shutdownImmediately() }
            var first: [Bool] = []
            runtime.beginVoiceSession { first.append($0) }
            runtime.endVoiceSession(); runtime.setReady(false)
            system.current = "airpods"; system.callback?()
            runtime.setReady(true)
            try check(system.current == "airpods" && system.writes.count == 2 && first == [true], "Recovered readiness silently started another voice")
            runtime.beginVoiceSession { _ in }; runtime.endVoiceSession()
            try check(system.current == "airpods" && system.writes.count == 4, "Next press reused the failed session's return target")
        }),
        ("priority opt-out during pending confirmation restores the late switch exactly once", {
            let (system, runtime, initial) = makeRuntime(.delayed)
            defer { runtime.shutdownImmediately() }
            var results: [Bool] = []
            runtime.beginVoiceSession { results.append($0) }
            var configuration = initial; configuration.preferVirtualInput = false
            runtime.configure(configuration)
            try check(results == [false], "Opt-out did not cancel the trigger gate")
            system.mode = .immediate; system.applyPending()
            configuration.preferVirtualInput = true; runtime.configure(configuration)
            try check(results == [false] && system.current == "built-in" && system.writes.count == 2, "Late switch or re-enable restarted the cancelled press")
        })
    ]
}
