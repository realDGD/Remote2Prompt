import AppKit
import CoreAudio
import Foundation
import Remote2PromptMac

/// Explicit hardware check: silence only, no input capture. Ordinary checks never call it.
@MainActor
func loopbackStreamSmoke(switchInput: Bool, jitter: Bool = false, extended: Bool = false) async throws {
    guard NSRunningApplication.runningApplications(withBundleIdentifier: "dev.remote2prompt.app").isEmpty else {
        throw Failure(message: "Quit Remote2Prompt before the hardware output check")
    }
    let devices = LoopbackDevices.available()
    guard devices.count == 1, let device = devices.first else {
        throw Failure(message: "Hardware check requires exactly one compatible loopback")
    }
    guard let before = LoopbackDevices.defaultSnapshot() else { throw Failure(message: "Cannot snapshot default devices") }
    let original = try readDefaultInput()
    let target = try inputID(for: device.uid)
    if switchInput && original == target { throw Failure(message: "Select a different system input before checking an input transition") }
    let writer = LoopbackWriter()
    var failure: (any Error)?
    var sessions = 0
    var submitted = 0
    var rapidCycles = 0
    do {
        let configured: Result<Void, LoopbackFailure> = await withCheckedContinuation { c in
            writer.configure(uid: device.uid) { c.resume(returning: $0) }
        }
        try configured.get()
        // Reuse one output across sessions: returning to a physical input must not poison the next press.
        for round in 0..<3 {
            writer.begin()
            let start = ProcessInfo.processInfo.systemUptime
            let buffers = extended && round == 0 ? 12000 : 800
            for index in 0..<buffers {
                if jitter && index > 0 && index % 80 == 0 { try await Task.sleep(for: .milliseconds(180)) }
                if switchInput && index == 100 {
                    guard setDefaultInput(target) == noErr else { throw Failure(message: "Input transition rejected") }
                }
                if switchInput && index == 400, try readDefaultInput() == target {
                    guard setDefaultInput(original) == noErr else { throw Failure(message: "Input restoration rejected") }
                }
                let error: LoopbackFailure? = await withCheckedContinuation { c in
                    writer.append([Int16](repeating: 0, count: 160)) { c.resume(returning: $0) }
                }
                if let error { throw error }
                submitted += 160
                if index % 100 == 0 {
                    let health: Result<LoopbackProgress, LoopbackFailure> = await withCheckedContinuation { c in
                        writer.checkHealth { c.resume(returning: $0) }
                    }
                    _ = try health.get()
                }
                let remaining = start + Double(index + 1) * 0.01 - ProcessInfo.processInfo.systemUptime
                if remaining > 0 { try await Task.sleep(for: .seconds(remaining)) }
            }
            let progress: LoopbackProgress = await withCheckedContinuation { c in writer.snapshot { c.resume(returning: $0) } }
            if jitter {
                try check(progress.playback.timingRecoveries > 0 && progress.playback.lateSchedules == 0, "Underrun kept scheduling behind the playback clock")
            }
            let drained: Bool = await withCheckedContinuation { c in writer.finish { c.resume(returning: $0) } }
            try check(drained, "Playback did not finish before the drain deadline")
            sessions += 1
        }
        if extended {
            for index in 0..<30 {
                writer.begin()
                let error: LoopbackFailure? = await withCheckedContinuation { c in
                    writer.append([Int16](repeating: 0, count: 320)) { c.resume(returning: $0) }
                }
                if let error { throw error }
                submitted += 320
                if index % 3 == 0 { writer.cancel() }
                else {
                    let drained: Bool = await withCheckedContinuation { c in writer.finish { c.resume(returning: $0) } }
                    try check(drained, "Rapid cycle did not drain")
                }
                rapidCycles += 1
            }
        }
    } catch { failure = error }
    // Await resource cleanup on success AND failure, rather than exiting while a restore is pending.
    await withCheckedContinuation { c in writer.stop { c.resume() } }
    if switchInput, try readDefaultInput() == target {
        guard setDefaultInput(original) == noErr else { throw Failure(message: "Input restoration rejected after playback") }
    }
    try await Task.sleep(for: .milliseconds(500))
    try check(before == LoopbackDevices.defaultSnapshot(), "Default input/output were not restored; external selections were respected")
    if let failure { throw failure }
    print("PASS continuous loopback: \(sessions) sessions, \(submitted) silent samples submitted; rapid cycles=\(rapidCycles); extended=\(extended); input transition=\(switchInput); jitter=\(jitter); defaults restored; no input capture")
}

private func readDefaultInput() throws -> AudioDeviceID {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var value: AudioDeviceID = 0; var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &value) == noErr else {
        throw Failure(message: "Cannot read system input")
    }
    return value
}
private func setDefaultInput(_ target: AudioDeviceID) -> OSStatus {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var value = target
    return AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &value)
}
private func inputID(for uid: String) throws -> AudioDeviceID {
    var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDeviceForUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
    var source: CFString = uid as CFString
    var value: AudioDeviceID = 0
    let status = withUnsafePointer(to: &source) { sourcePointer in
        withUnsafeMutablePointer(to: &value) { output in
            var translation = AudioValueTranslation(mInputData: UnsafeMutableRawPointer(mutating: sourcePointer), mInputDataSize: UInt32(MemoryLayout<CFString>.size), mOutputData: output, mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size))
            var size = UInt32(MemoryLayout<AudioValueTranslation>.size)
            return AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &translation)
        }
    }
    guard status == noErr, value != 0 else { throw Failure(message: "Selected loopback disappeared") }
    return value
}
