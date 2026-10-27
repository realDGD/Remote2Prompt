import Foundation
import Combine
import Remote2PromptCore

@MainActor
final class ProbeInputs: AudioInputSystem {
    var starts = 0
    var stops = 0
    var reads = 0
    var writes = 0
    var startFails = false
    var current = "fixture-physical"
    var callback: (@MainActor () -> Void)?
    func start(onChange: @escaping @MainActor () -> Void) throws {
        starts += 1
        if startFails { throw InputSystemFailure.unavailable }
        callback = onChange
    }
    func snapshot() throws -> SystemInputSnapshot {
        reads += 1
        return SystemInputSnapshot(inputs: [
            SystemAudioInput(policy: AudioInput(uid: "fixture-physical", isVirtual: false), name: "Fixture physical"),
            SystemAudioInput(policy: AudioInput(uid: "fixture-virtual", isVirtual: true), name: "Fixture virtual")
        ], defaultUID: current)
    }
    func setDefaultInput(_ request: InputPriorityRequest) throws {
        guard request.sourceUID == current else { throw InputSystemFailure.defaultChanged }
        writes += 1; current = request.targetUID; callback?()
    }
    func stop() { stops += 1; callback = nil }
}

@main
struct InputRuntimeProbe {
    @MainActor static func pump(_ duration: TimeInterval) {
        let limit = Date().addingTimeInterval(duration)
        while Date() < limit { _ = RunLoop.main.run(mode: .default, before: min(limit, Date().addingTimeInterval(0.05))) }
    }
    @MainActor static func main() {
        let idle = ProbeInputs()
        var runtime: AudioInputPriorityRuntime? = AudioInputPriorityRuntime(system: idle)
        var publications = 0
        let observer = runtime!.$state.sink { _ in publications += 1 }
        runtime!.configure(AppConfiguration())
        let readsBefore = idle.reads; let updatesBefore = publications
        pump(6.2)
        print("IDLE opt_in_off duration_s=6.2 snapshot_reads=\(idle.reads - readsBefore) state_publications=\(publications - updatesBefore) fake_writes=\(idle.writes)")
        precondition(idle.writes == 0)
        var finished = false
        runtime!.shutdown { finished = true }
        let readsAfterStop = idle.reads
        observer.cancel()
        weak var weakRuntime = runtime
        runtime = nil
        pump(2.2)
        print("SHUTDOWN completed=\(finished) callback_removed=\(idle.callback == nil) runtime_released=\(weakRuntime == nil) later_reads=\(idle.reads - readsAfterStop)")
        precondition(finished && idle.callback == nil && weakRuntime == nil && idle.reads == readsAfterStop)

        weakRuntime = nil

        var completedCycles = 0
        var retainedRuntimes = 0
        for _ in 0..<1000 {
            weak var previous: AudioInputPriorityRuntime?
            autoreleasepool {
                let system = ProbeInputs()
                let value = AudioInputPriorityRuntime(system: system)
                previous = value
                var config = AppConfiguration()
                config.preferVirtualInput = true; config.voiceEnabled = true; config.remoteAudioEnabled = true
                config.selectedVirtualInputUID = "fixture-virtual"
                value.configure(config); value.setReady(true)
                var permitted = false
                value.beginVoiceSession { permitted = $0 }
                value.endVoiceSession()
                var stopped = false
                value.shutdown { stopped = true }
                precondition(permitted && stopped && system.writes == 2 && system.callback == nil && system.stops == 1)
                precondition(system.current == "fixture-physical")
                completedCycles += 1
            }
            if previous != nil { retainedRuntimes += 1 }
        }
        print("STRESS cycles=\(completedCycles) retained_runtimes=\(retainedRuntimes) all_fake_inputs_restored=true")
        precondition(retainedRuntimes == 0)

        let recovering = ProbeInputs(); recovering.startFails = true
        let failed = AudioInputPriorityRuntime(system: recovering)
        recovering.startFails = false
        let startsBefore = recovering.starts
        failed.refreshInputs()
        print("RECOVERY menu_refresh_restarts=\(recovering.starts - startsBefore) phase_after_menu_refresh=\(failed.state.phase) catalog_count=\(failed.state.inputs.count)")
        failed.retry()
        print("RECOVERY explicit_retry_starts=\(recovering.starts - startsBefore) phase_after_retry=\(failed.state.phase) catalog_count=\(failed.state.inputs.count)")
        precondition(recovering.starts == startsBefore + 1 && failed.state.inputs.count == 2)
        failed.shutdownImmediately()
        print("NO_HARDWARE all observations and writes used ProbeInputs; CoreAudioInputSystem was never instantiated")
    }
}
