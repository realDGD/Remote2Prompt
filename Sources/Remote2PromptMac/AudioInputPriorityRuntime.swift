import AppKit
import Combine
import Foundation
import Remote2PromptCore

@MainActor
public final class AudioInputPriorityRuntime: ObservableObject {
    @Published public private(set) var state = InputPriorityState()
    private let coordinator: InputPriorityCoordinator
    private let hardwareEnabled: Bool
    private var configuration = AppConfiguration()
    private var ready = false
    private var voiceActive = false
    private var beginCompletion: ((Bool) -> Void)?
    private var beginDeadline: TimeInterval?
    private var periodic: Timer?
    private var wakeup: Timer?
    private var wakeupAt: TimeInterval?
    private var closing = false
    private var closed = false
    private var deadline: TimeInterval?
    private var completions: [() -> Void] = []

    public init(hardwareEnabled: Bool = true, system: (any AudioInputSystem)? = nil) {
        self.hardwareEnabled = hardwareEnabled
        coordinator = InputPriorityCoordinator(system: system ?? CoreAudioInputSystem())
        coordinator.onUpdate = { [weak self] in self?.updated() }
        guard hardwareEnabled else { return }
        coordinator.start()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.coordinator.refresh() }
        }
        periodic = timer; RunLoop.main.add(timer, forMode: .common)
    }
    public func configure(_ value: AppConfiguration) {
        guard hardwareEnabled, !closing, !closed else { return }
        configuration = value; apply()
    }
    public func setReady(_ value: Bool) {
        guard hardwareEnabled, !closing, !closed, ready != value else { return }
        ready = value; apply()
    }
    public func retry() { guard hardwareEnabled, !closing, !closed else { return }; coordinator.retry() }
    public var canSelectInput: Bool { hardwareEnabled && !closing && !closed && coordinator.canSelectInput }
    public func selectInput(uid: String) { guard canSelectInput else { return }; coordinator.selectInput(uid: uid) }
    public func refreshInputs() { guard hardwareEnabled, !closing, !closed else { return }; coordinator.refresh() }
    /// The trigger may be sent only after a fresh, matching CoreAudio readback.
    public func beginVoiceSession(completion: @escaping (Bool) -> Void) {
        guard hardwareEnabled, !closing, !closed else { completion(false); return }
        guard !state.selectingInput else { completion(false); return }
        guard configuration.preferVirtualInput else { completion(true); return }
        guard ready, configuration.voiceEnabled, configuration.remoteAudioEnabled else { completion(false); return }
        completeBegin(false)
        voiceActive = true
        beginCompletion = completion
        beginDeadline = ProcessInfo.processInfo.systemUptime + 3.5
        apply()
    }
    public func endVoiceSession() {
        voiceActive = false
        let completion = beginCompletion
        beginCompletion = nil; beginDeadline = nil
        if hardwareEnabled, !closing, !closed { apply() }
        completion?(false)
    }
    private func apply() {
        coordinator.configure(enabled: configuration.preferVirtualInput, selectedUID: configuration.selectedVirtualInputUID,
                              activeVoices: voiceActive && ready && configuration.voiceEnabled && configuration.remoteAudioEnabled ? ["remote-audio"] : [])
    }

    /// AppKit keeps the run loop alive while this bounded restore/readback transaction completes.
    public func shutdown(completion: @escaping () -> Void) {
        if closed { completion(); return }
        completions.append(completion)
        guard !closing else { return }
        closing = true; voiceActive = false
        completeBegin(false)
        deadline = ProcessInfo.processInfo.systemUptime + 3.5
        if hardwareEnabled { coordinator.configure(enabled: false, selectedUID: nil, activeVoices: []) }
        updated()
    }
    public func shutdownImmediately() {
        guard !closed else { return }
        closing = true; deadline = ProcessInfo.processInfo.systemUptime
        completeBegin(false)
        if hardwareEnabled { coordinator.configure(enabled: false, selectedUID: nil, activeVoices: []) }
        finish()
    }
    private func updated() {
        guard !closed else { return }
        if state != coordinator.state { state = coordinator.state }
        let now = ProcessInfo.processInfo.systemUptime
        if beginCompletion != nil {
            if state.readyForVoice && ready && voiceActive && configuration.preferVirtualInput { completeBegin(true) }
            else if !ready || !configuration.preferVirtualInput || now >= (beginDeadline ?? now)
                || state.phase == .failed && !state.pending && !coordinator.hasPressSnapshot
                || [.paused, .stopped, .waiting].contains(state.phase) && !state.pending { completeBegin(false) }
        }
        if closing && (!hardwareEnabled || coordinator.canFinishShutdown || now >= (deadline ?? now)) { finish(); return }
        var next = coordinator.nextWakeup
        if let beginDeadline { next = min(next ?? beginDeadline, beginDeadline) }
        if closing, let deadline { next = min(next ?? deadline, deadline) }
        guard next != wakeupAt else { return }
        wakeup?.invalidate(); wakeup = nil; wakeupAt = next
        guard let next else { return }
        let timer = Timer(timeInterval: max(0.01, next - now), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.closed else { return }
                self.wakeup = nil; self.wakeupAt = nil
                self.coordinator.refresh(); self.updated()
            }
        }
        wakeup = timer
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .modalPanel)
    }
    private func finish() {
        guard !closed else { return }
        closed = true
        completeBegin(false)
        periodic?.invalidate(); periodic = nil
        wakeup?.invalidate(); wakeup = nil; wakeupAt = nil
        let unconfirmed = coordinator.hasUnrestoredSession
        coordinator.stop()
        state = coordinator.state
        if unconfirmed { state.error = "退出前未能确认输入恢复，请检查系统输入设备。" }
        let callbacks = completions; completions.removeAll()
        callbacks.forEach { $0() }
    }
    private func completeBegin(_ success: Bool) {
        let callback = beginCompletion
        beginCompletion = nil; beginDeadline = nil
        if !success, callback != nil, voiceActive {
            voiceActive = false
            if hardwareEnabled, !closing, !closed { apply() }
        }
        callback?(success)
    }
}
