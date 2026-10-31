import AppKit
import Foundation
import VoiRemoteCore
import VoiRemoteMac

/// Explicit device check. It emulates voice boundaries, not HID, BLE, key posting or recognition.
@MainActor
func voiceInputSessionSmoke() async throws {
    guard NSRunningApplication.runningApplications(withBundleIdentifier: "dev.voiremote.app").isEmpty else {
        throw Failure(message: "Quit VoiRemote before the input-session hardware check")
    }
    let devices = LoopbackDevices.available()
    guard devices.count == 1, let device = devices.first, let defaults = LoopbackDevices.defaultSnapshot() else {
        throw Failure(message: "Requires one compatible loopback and readable default devices")
    }
    let system = CoreAudioInputSystem()
    let initial = try system.snapshot()
    guard let original = initial.defaultUID, original != device.uid else {
        throw Failure(message: "Requires a different original input")
    }
    let runtime = AudioInputPriorityRuntime(system: system)
    let writer = LoopbackWriter()
    var failure: (any Error)?
    var rounds = 0
    do {
        let configured: Result<Void, LoopbackFailure> = await withCheckedContinuation { c in
            writer.configure(uid: device.uid) { c.resume(returning: $0) }
        }
        try configured.get()
        var configuration = AppConfiguration()
        configuration.preferVirtualInput = true; configuration.voiceEnabled = true
        configuration.remoteAudioEnabled = true; configuration.selectedVirtualInputUID = device.uid
        runtime.configure(configuration); runtime.setReady(true)
        try check(try system.snapshot().defaultUID == original, "Idle readiness changed the input")
        for round in 0..<3 {
            var permitted: Bool?
            runtime.beginVoiceSession { permitted = $0 }
            try await waitForInput(runtime) { permitted != nil }
            try check(permitted == true && (try system.snapshot().defaultUID) == device.uid, "Press did not confirm virtual input")
            writer.begin()
            let start = ProcessInfo.processInfo.systemUptime
            for index in 0..<200 {
                if round == 0 && index == 60 {
                    // Reproduce an external physical-input preemption while the voice is held.
                    try system.setDefaultInput(InputPriorityRequest(sequence: 0, sourceUID: device.uid, targetUID: original, purpose: .userSelection))
                }
                runtime.refreshInputs()
                if index >= 120 {
                    try check(try system.snapshot().defaultUID == device.uid, "Held voice did not reclaim virtual input")
                }
                let error: LoopbackFailure? = await withCheckedContinuation { c in
                    writer.append([Int16](repeating: 0, count: 160)) { c.resume(returning: $0) }
                }
                if let error { throw error }
                let remaining = start + Double(index + 1) * 0.01 - ProcessInfo.processInfo.systemUptime
                if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
            }
            let drained: Bool = await withCheckedContinuation { c in writer.finish { c.resume(returning: $0) } }
            try check(drained, "Output failed to drain before release")
            runtime.endVoiceSession()
            try await waitForInput(runtime) { !runtime.state.pending && runtime.state.defaultUID == original }
            try check(try system.snapshot().defaultUID == original, "Release did not restore the exact original input")
            rounds += 1
        }
    } catch { failure = error }
    runtime.endVoiceSession()
    var stopped = false
    runtime.shutdown { stopped = true }
    do { try await waitForInput(runtime) { stopped } } catch { if failure == nil { failure = error } }
    await withCheckedContinuation { c in writer.stop { c.resume() } }
    // Last-resort restoration only if this check still owns the virtual choice.
    if let current = try? system.snapshot(), current.defaultUID == device.uid {
        let cleanup = CoreAudioInputSystem()
        try cleanup.start(onChange: {})
        defer { cleanup.stop() }
        try cleanup.setDefaultInput(InputPriorityRequest(sequence: 0, sourceUID: device.uid, targetUID: original, purpose: .restore))
    }
    runtime.shutdownImmediately()
    try await Task.sleep(for: .milliseconds(500))
    try check(system.listenerCount == 0 && defaults == LoopbackDevices.defaultSnapshot(), "Listeners leaked or default devices were not restored")
    if let failure { throw failure }
    print("PASS voice input transaction: \(rounds) confirmed presses, held preemption reclaimed, exact input restored after each drain, listeners removed, output unchanged; silence only")
}

@MainActor
private func waitForInput(_ runtime: AudioInputPriorityRuntime, until ready: () -> Bool) async throws {
    let deadline = ProcessInfo.processInfo.systemUptime + 4
    while !ready() && ProcessInfo.processInfo.systemUptime < deadline {
        // CLI async main has no AppKit run loop; explicitly refresh the real production coordinator.
        runtime.refreshInputs()
        if !ready() { try await Task.sleep(for: .milliseconds(20)) }
    }
    try check(ready(), "Input transaction exceeded its confirmation window")
}
