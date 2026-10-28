import Darwin
import Foundation
import Remote2PromptCore
import Remote2PromptMac

@MainActor private final class ReminderReads { var count = 0 }

/// Uses the real Task scheduler, rather than the fake deadline used by timing checks.
@MainActor private func exerciseReminderOwners(_ cycles: Int) async throws -> Int {
    let reads = ReminderReads()
    var c = AppConfiguration(); c.voiceEnabled = true; c.remoteAudioEnabled = true; c.voiceLimitReminderEnabled = true
    for index in 0..<cycles {
        var owner: VoiceLimitReminderRuntime? = VoiceLimitReminderRuntime(clock: {
            reads.count += 1; return ProcessInfo.processInfo.systemUptime
        })
        weak var released = owner
        var p = VoiceLimitIndicator()
        p.begin(segment: 1, at: ProcessInfo.processInfo.systemUptime, hasRC003Limit: true)
        owner?.configure(c); owner?.update(p); owner?.preview()
        if index.isMultiple(of: 2) { owner?.shutdown() }
        owner = nil
        try check(released == nil, "A real deadline retained its reminder owner")
    }
    let before = reads.count
    // Let cancelled Task closures execute; no Task may re-enter a released owner.
    try await Task.sleep(for: .milliseconds(50))
    try check(reads.count == before, "A released reminder performed a late refresh")
    return cycles
}

private func ownResidentBytes() -> UInt64? {
    var info = mach_task_basic_info()
    let capacity = MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
    var count = mach_msg_type_number_t(capacity)
    let status = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: capacity) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    return status == KERN_SUCCESS ? UInt64(info.resident_size) : nil
}

@MainActor func reminderResourceChecks() -> [(String, @MainActor () async throws -> Void)] {
    [("real reminder deadlines release owners with and without explicit shutdown", {
        _ = try await exerciseReminderOwners(100)
    })]
}

/// Optional measurement, not a CI memory threshold. No AppKit, panel, HID or audio resource is opened.
@MainActor func voiceReminderResourceProbe() async throws {
    var released = try await exerciseReminderOwners(200)
    var samples: [UInt64] = []
    guard let baseline = ownResidentBytes() else { throw Failure(message: "Cannot read own process RSS") }
    samples.append(baseline)
    for _ in 0..<3 {
        released += try await exerciseReminderOwners(1000)
        guard let rss = ownResidentBytes() else { throw Failure(message: "Cannot read own process RSS") }
        samples.append(rss)
    }
    let summary = samples.map(String.init).joined(separator: ",")
    print("Reminder resource probe passed: ownersReleased=\(released), lateRefreshes=0, RSS bytes warm/1000/2000/3000=[\(summary)]")
    print("RSS includes Swift/Combine allocator caches; no panel or real audio was measured, no memory threshold claimed")
}
