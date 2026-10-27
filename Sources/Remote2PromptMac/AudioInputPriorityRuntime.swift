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
    private func apply() {
        coordinator.configure(enabled: configuration.preferVirtualInput, selectedUID: configuration.selectedVirtualInputUID,
                              readyRemotes: ready && configuration.voiceEnabled && configuration.remoteAudioEnabled ? ["remote-audio"] : [])
    }

    /// AppKit keeps the run loop alive while this bounded restore/readback transaction completes.
    public func shutdown(completion: @escaping () -> Void) {
        if closed { completion(); return }
        completions.append(completion)
        guard !closing else { return }
        closing = true; deadline = ProcessInfo.processInfo.systemUptime + 3.5
        if hardwareEnabled { coordinator.configure(enabled: false, selectedUID: nil, readyRemotes: []) }
        updated()
    }
    public func shutdownImmediately() {
        guard !closed else { return }
        closing = true; deadline = ProcessInfo.processInfo.systemUptime
        if hardwareEnabled { coordinator.configure(enabled: false, selectedUID: nil, readyRemotes: []) }
        finish()
    }
    private func updated() {
        if state != coordinator.state { state = coordinator.state }
        guard !closed else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if closing && (!hardwareEnabled || coordinator.canFinishShutdown || now >= (deadline ?? now)) { finish(); return }
        var next = coordinator.nextWakeup
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
        periodic?.invalidate(); periodic = nil
        wakeup?.invalidate(); wakeup = nil; wakeupAt = nil
        let unconfirmed = !coordinator.canFinishShutdown
        coordinator.stop()
        state = coordinator.state
        if unconfirmed { state.error = "退出前未能确认输入恢复，请检查系统输入设备。" }
        let callbacks = completions; completions.removeAll()
        callbacks.forEach { $0() }
    }
}
