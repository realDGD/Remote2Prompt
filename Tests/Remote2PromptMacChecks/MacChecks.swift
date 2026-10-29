import ApplicationServices
import Foundation
import IOKit.hidsystem
import Remote2PromptCore
import Remote2PromptMac

struct Failure: Error { let message: String }
func check(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw Failure(message: message) }
}

@MainActor
final class FakeService {
    var mappings: [UsageMapping] = []
    var rejects = false
    var ignoresWrites = false
    var writes = 0
    func service(_ id: UInt64 = 1) -> HIDMappingService {
        HIDMappingService(id: id, read: { self.mappings }, write: {
            self.writes += 1
            if self.rejects { return false }
            if self.ignoresWrites { return true }
            self.mappings = $0
            return true
        })
    }
}

@main
enum MacChecks {
    @MainActor
    static func main() async throws {
        if CommandLine.arguments.contains("--voice-reminder-resource-probe") {
            try await voiceReminderResourceProbe()
            return
        }
        if CommandLine.arguments.contains("--voice-input-session-smoke") {
            do { try await voiceInputSessionSmoke() }
            catch { print("FAIL voice input transaction: \(error)"); exit(1) }
            return
        }
        if CommandLine.arguments.contains("--loopback-stream-smoke") {
            do { try await loopbackStreamSmoke(switchInput: CommandLine.arguments.contains("--switch-input"), jitter: CommandLine.arguments.contains("--jitter"), extended: CommandLine.arguments.contains("--extended")) }
            catch { print("FAIL continuous loopback: \(error)"); exit(1) }
            return
        }
        if CommandLine.arguments.contains("--loopback-output-smoke") {
            guard let before = LoopbackDevices.defaultSnapshot() else { throw Failure(message: "Cannot read default audio devices") }
            guard let device = LoopbackDevices.available().first else { throw Failure(message: "No compatible loopback device installed") }
            let writer = LoopbackWriter()
            let failure: String? = await withCheckedContinuation { continuation in
                writer.configure(uid: device.uid) { result in
                    switch result {
                    case .failure(let error): continuation.resume(returning: error.localizedDescription)
                    case .success:
                        writer.append([Int16](repeating: 0, count: 800)) { error in
                            if let error {
                                writer.stop { continuation.resume(returning: error.localizedDescription) }
                            } else {
                                writer.finish { completed in
                                    writer.stop { continuation.resume(returning: completed ? nil : "Silent PCM did not drain") }
                                }
                            }
                        }
                    }
                }
            }
            if let failure { throw Failure(message: failure) }
            try check(LoopbackDevices.defaultSnapshot() == before, "System default input/output changed during the output check")
            print("PASS loopback output smoke: \(device.name), 800 silent PCM samples drained; no microphone capture or default-device changes")
            return
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var cases: [(String, @MainActor () throws -> Void)] = [
            ("voice-only lease preserves ordinary native keys across recovery", {
                let service = FakeService()
                let power = UsageMapping(source: UInt64(7) << 32 | 0x66, destination: 123)
                service.mappings = [power]
                let path = directory.appendingPathComponent("voice-only.json")
                let lease = try NativeKeyLease(url: path, boot: 1, services: { [service.service()] })
                let voiceSource = UInt64(7) << 32 | UInt64(XiaomiRemote.voiceUsage)
                try lease.acquire(sources: [voiceSource])
                try check(service.mappings.count == 2 && service.mappings.contains(power), "Voice-only mode changed ordinary keys")
                let next = try NativeKeyLease(url: path, boot: 1, services: { [service.service()] })
                try next.restore()
                try check(service.mappings == [power], "Voice-only recovery lost scope")
            }),
            ("device lease restores original and preserves unrelated edits", {
                let service = FakeService()
                let original = UsageMapping(source: UInt64(7) << 32 | 0x66, destination: UInt64(7) << 32 | 0x6F)
                service.mappings = [original]
                let lease = try NativeKeyLease(url: directory.appendingPathComponent("restore.json"), boot: 1, services: { [service.service()] })
                try lease.acquire()
                try check(try lease.verifyCoverage(), "Lease not verified")
                let external = UsageMapping(source: 12345, destination: 67890)
                service.mappings.append(external)
                try lease.restore()
                try check(service.mappings.contains(original) && service.mappings.contains(external), "Restore lost original or external mapping")
                try check(!lease.hasPendingRecovery, "Recovery remained pending")
            }),
            ("external replacement of an owned key is retained", {
                let service = FakeService()
                let lease = try NativeKeyLease(url: directory.appendingPathComponent("external.json"), boot: 1, services: { [service.service()] })
                try lease.acquire()
                let source = UInt64(7) << 32 | 0x66
                service.mappings.removeAll { $0.source == source }
                let external = UsageMapping(source: source, destination: 99)
                service.mappings.append(external)
                try check(try !lease.verifyCoverage(), "External modification went unnoticed")
                try lease.restore()
                try check(service.mappings == [external], "External owned-source edit was overwritten")
            }),
            ("partial application rolls earlier services back", {
                let a = FakeService(); let b = FakeService(); b.rejects = true
                let lease = try NativeKeyLease(url: directory.appendingPathComponent("partial.json"), boot: 1, services: { [a.service(1), b.service(2)] })
                do { try lease.acquire(); throw Failure(message: "Partial application accepted") }
                catch is MappingFailure {}
                try check(a.mappings.isEmpty, "Earlier service was left neutralized")
                try check(lease.hasPendingRecovery, "Failed recovery was forgotten")
                b.rejects = false
                try lease.restore()
                try check(!lease.hasPendingRecovery, "Retry did not clear recovery")
            }),
            ("journal must be writable before native keys change", {
                let service = FakeService()
                let lease = try NativeKeyLease(url: URL(fileURLWithPath: "/dev/null/recovery.json"), boot: 1, services: { [service.service()] })
                do { try lease.acquire(); throw Failure(message: "Unwritable journal accepted") }
                catch is Failure { throw Failure(message: "Unwritable journal accepted") }
                catch {}
                try check(service.writes == 0, "Keys changed before journal was saved")
            }),
            ("next launch recovers a prior same-boot lease", {
                let service = FakeService()
                let url = directory.appendingPathComponent("crash.json")
                let first = try NativeKeyLease(url: url, boot: 1, services: { [service.service()] })
                try first.acquire()
                let next = try NativeKeyLease(url: url, boot: 1, services: { [service.service()] })
                try next.restore()
                try check(service.mappings.isEmpty, "Interrupted lease was not restored")
            }),
            ("another boot does not restore reused registry IDs", {
                let service = FakeService(); let url = directory.appendingPathComponent("boot.json")
                let first = try NativeKeyLease(url: url, boot: 1, services: { [service.service()] })
                try first.acquire()
                service.mappings = [UsageMapping(source: 999, destination: 888)]
                let next = try NativeKeyLease(url: url, boot: 2, services: { [service.service()] })
                try next.restore()
                try check(service.mappings == [UsageMapping(source: 999, destination: 888)], "Previous boot modified a new device")
            }),
            ("no matching service cannot acquire a lease", {
                let lease = try NativeKeyLease(url: directory.appendingPathComponent("empty.json"), boot: 1, services: { [] })
                do { try lease.acquire(); throw Failure(message: "No-device lease accepted") }
                catch MappingFailure.noService {}
            }),
            ("successful write without matching readback is rejected", {
                let service = FakeService(); service.ignoresWrites = true
                let lease = try NativeKeyLease(url: directory.appendingPathComponent("readback.json"), boot: 1, services: { [service.service()] })
                do { try lease.acquire(); throw Failure(message: "Unverified write was accepted") }
                catch MappingFailure.writeFailed {}
                try check(service.mappings.isEmpty, "Unverified service state changed")
            }),
            ("corrupt recovery file prevents device writes", {
                let service = FakeService(); let url = directory.appendingPathComponent("corrupt.json")
                try Data("invalid journal".utf8).write(to: url)
                do {
                    _ = try NativeKeyLease(url: url, boot: 1, services: { [service.service()] })
                    throw Failure(message: "Corrupt recovery data accepted")
                } catch is DecodingError {}
                try check(service.writes == 0, "Corrupt journal changed native keys")
            }),
            ("removed services are not restored onto other devices", {
                let service = FakeService(); var present = true
                let lease = try NativeKeyLease(url: directory.appendingPathComponent("removed.json"), boot: 1, services: { present ? [service.service()] : [] })
                try lease.acquire(); let writes = service.writes; present = false
                try lease.restore()
                try check(service.writes == writes && !lease.hasPendingRecovery, "Removed service was written or kept pending")
            }),
            ("new sibling service invalidates coverage", {
                let a = FakeService(); let b = FakeService(); var includeSibling = false
                let lease = try NativeKeyLease(url: directory.appendingPathComponent("sibling.json"), boot: 1, services: {
                    includeSibling ? [a.service(1), b.service(2)] : [a.service(1)]
                })
                try lease.acquire(); includeSibling = true
                try check(try !lease.verifyCoverage(), "New interface was treated as suppressed")
                try lease.restore()
            }),
            ("Control events use distinct keycodes and sided flags", {
                for (trigger, mask) in [(VoiceTrigger.leftControl, NX_DEVICELCTLKEYMASK), (.rightControl, NX_DEVICERCTLKEYMASK)] {
                    var events: [CGEvent] = []
                    let sender = SystemActionSender(permission: { true }, physicalKeyDown: { _ in false }, physicalFlags: { [] }, post: { events.append($0) })
                    try sender.voice(VoiceKeyEvent(trigger: trigger, isDown: true))
                    try sender.releaseAll()
                    try sender.releaseAll()
                    try check(events.count == 2, "Voice was not paired exactly once")
                    try check(events[0].type == .flagsChanged && events[0].getIntegerValueField(.keyboardEventKeycode) == Int64(trigger.virtualKeyCode), "Wrong event type or side")
                    try check(events[0].flags.contains(.maskControl) && events[0].flags.rawValue & UInt64(mask) != 0, "Missing side flag")
                }
            }),
            ("release is attempted after permission loss", {
                var granted = true; var events: [CGEvent] = []
                let sender = SystemActionSender(permission: { granted }, physicalKeyDown: { _ in false }, physicalFlags: { [] }, post: { events.append($0) })
                try sender.voice(VoiceKeyEvent(trigger: .rightControl, isDown: true))
                granted = false; try sender.releaseAll()
                try check(events.count == 2, "Permission loss prevented cleanup")
                do { try sender.perform(MappedInvocation(action: .copy)); throw Failure(message: "Action posted without permission") }
                catch ActionFailure.accessibility {}
            }),
            ("held physical modifier blocks synthetic takeover", {
                var events: [CGEvent] = []
                let sender = SystemActionSender(permission: { true }, physicalKeyDown: { _ in true }, physicalFlags: { [] }, post: { events.append($0) })
                do { try sender.voice(VoiceKeyEvent(trigger: .leftControl, isDown: true)); throw Failure(message: "Physical modifier taken over") }
                catch ActionFailure.physicalModifier {}
                try check(events.isEmpty, "Physical conflict posted an event")
            }),
            ("voice release preserves other physical modifiers", {
                var events: [CGEvent] = []
                let sender = SystemActionSender(permission: { true }, physicalKeyDown: { _ in false }, physicalFlags: { .maskShift }, post: { events.append($0) })
                try sender.voice(VoiceKeyEvent(trigger: .leftControl, isDown: true))
                try sender.releaseAll()
                try check(events.last?.flags.contains(.maskShift) == true, "Release discarded a physically held Shift")
                try check(events.last?.flags.contains(.maskControl) == false, "Release left synthetic Control held")
            }),
            ("voice release clears stale synthetic flags from the global snapshot", {
                var events: [CGEvent] = []
                let flags: CGEventFlags = [.maskControl, .maskShift, CGEventFlags(rawValue: UInt64(NX_DEVICELCTLKEYMASK))]
                let sender = SystemActionSender(permission: { true }, physicalKeyDown: { _ in false }, physicalFlags: { flags }, post: { events.append($0) })
                try sender.voice(VoiceKeyEvent(trigger: .leftControl, isDown: true)); try sender.releaseAll()
                try check(events.last?.flags == .maskShift, "Synthetic hold survived its own release")
            }),
            ("voice release keeps a physical opposite-side modifier", {
                var events: [CGEvent] = []
                let sender = SystemActionSender(permission: { true }, physicalKeyDown: { $0 == 62 }, physicalFlags: { .maskControl }, post: { events.append($0) })
                try sender.voice(VoiceKeyEvent(trigger: .leftControl, isDown: true)); try sender.releaseAll()
                try check(events.last?.flags.contains(.maskControl) == true, "Physical right Control was cleared")
                try check((events.last?.flags.rawValue ?? 0) & UInt64(NX_DEVICELCTLKEYMASK) == 0, "Synthetic left Control remained")
                try check((events.last?.flags.rawValue ?? 0) & UInt64(NX_DEVICERCTLKEYMASK) != 0, "Physical right-side flag lost")
            }),
            ("Fn voice trigger uses its own flag and releases it", {
                var events: [CGEvent] = []
                let sender = SystemActionSender(permission: { true }, physicalKeyDown: { _ in false }, physicalFlags: { [.maskSecondaryFn, .maskShift] }, post: { events.append($0) })
                try sender.voice(VoiceKeyEvent(trigger: .function, isDown: true)); try sender.releaseAll()
                try check(events.count == 2 && events.first?.getIntegerValueField(.keyboardEventKeycode) == 63, "Fn keycode or pair missing")
                try check(events.first?.flags.contains(.maskSecondaryFn) == true && events.first?.flags.contains(.maskControl) == false, "Fn became a Control combination")
                try check(events.last?.flags == .maskShift, "Fn flag remained held")
            }),
            ("shortcuts and media create tagged down/up pairs", {
                var events: [CGEvent] = []
                let sender = SystemActionSender(permission: { true }, physicalKeyDown: { _ in false }, physicalFlags: { [] }, post: { events.append($0) })
                try sender.perform(MappedInvocation(action: .customShortcut, shortcut: KeyboardShortcut(keyCode: 99, modifiers: [.control, .shift])))
                try check(events.count == 2 && events[0].flags.contains([.maskControl, .maskShift]), "Shortcut flags lost")
                try sender.perform(MappedInvocation(action: .volumeUp))
                try check(events.count == 4 && events.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == SystemActionSender.eventTag }, "Events missing origin tags")
                try sender.perform(MappedInvocation(action: .copy))
                let resolved = MappedInvocation(action: .copy).resolvedShortcut
                try check(events.count == 6 && resolved?.keyCode == 8 && resolved?.modifiers == .command, "Copy did not expose its actual shortcut")
                try check(events[4].getIntegerValueField(.keyboardEventKeycode) == Int64(resolved!.keyCode) && events[4].flags == .maskCommand, "Displayed output differs from posted copy shortcut")
            })
        ]
        cases.append(contentsOf: inputPriorityAdapterChecks())
        cases.append(contentsOf: loopbackWriterChecks())
        cases.append(contentsOf: voiceLimitReminderChecks())
        cases.append(contentsOf: weTypeCapsuleFollowerChecks())
        var failures = 0
        for (name, run) in cases {
            do { try run(); print("PASS \(name)") }
            catch { failures += 1; print("FAIL \(name): \(error)") }
        }
        let asyncCases = remoteAudioRuntimeChecks() + reminderResourceChecks()
        for (name, run) in asyncCases {
            do { try await run(); print("PASS \(name)") }
            catch { failures += 1; print("FAIL \(name): \(error)") }
        }
        let total = cases.count + asyncCases.count
        print("\(total - failures)/\(total) macOS adapter checks passed (no real input posted)")
        if failures > 0 { exit(1) }
    }
}
