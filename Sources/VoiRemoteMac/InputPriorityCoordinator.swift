import Foundation
import VoiRemoteCore

public struct InputPriorityState: Equatable, Sendable {
    public enum Phase: Sendable { case disabled, waiting, unchanged, maintaining, requesting, restoring, noFallback, failed, paused, stopped }
    public var phase: Phase = .disabled
    public var observedInput: String?
    public var requestedInput: String?
    public var confirmedInput: String?
    public var restoreInput: String?
    public var error: String?
    public var ownsInput = false
    public var pending = false
    public var readyForVoice = false
    public var usingFallback = false
    public var inputs: [SystemAudioInput] = []
    public var defaultUID: String?
    public var selectingInput = false
    public var selectionError: String?
    public init() {}
}

/// Serialized by MainActor. Notification payloads are hints; every decision uses a fresh system snapshot.
@MainActor
public final class InputPriorityCoordinator {
    public private(set) var state = InputPriorityState()
    public private(set) var nextWakeup: TimeInterval?
    public var onUpdate: (() -> Void)?
    public var hasUnrestoredSession: Bool { policy.hasSession }
    var hasPressSnapshot: Bool { policy.restoreInputUID != nil }
    public var canFinishShutdown: Bool {
        pending == nil && (!policy.hasSession || state.phase == .paused || state.phase == .noFallback)
    }
    private struct Pending {
        let request: InputPriorityRequest
        let deadline: TimeInterval
    }
    private struct Intent: Equatable {
        let source: String
        let target: String
        let purpose: InputPriorityRequest.Purpose
        init(_ request: InputPriorityRequest) { source = request.sourceUID; target = request.targetUID; purpose = request.purpose }
    }
    private let system: any AudioInputSystem
    private let clock: () -> TimeInterval
    private var policy = AudioInputPriority()
    private var enabled = false
    private var selectedUID: String?
    private var activeVoices: Set<String> = []
    private var pending: Pending?
    private var userSelection: Pending?
    private var intent: Intent?
    private var failures = 0
    private var nextWrite: TimeInterval = 0
    private var running = false
    private var stopped = false
    private var refreshing = false
    private var refreshAgain = false

    public init(system: any AudioInputSystem, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.system = system; self.clock = clock
    }

    public func start() {
        guard !running, !stopped else { return }
        do {
            try system.start { [weak self] in self?.refresh() }
            running = true; refresh()
        } catch {
            system.stop(); state.phase = .failed; state.error = error.localizedDescription
            onUpdate?()
        }
    }

    public func configure(enabled: Bool, selectedUID: String?, activeVoices: Set<String>) {
        guard !stopped else { return }
        let boundary = self.activeVoices.isEmpty != activeVoices.isEmpty || self.enabled != enabled
        let changed = self.enabled != enabled || self.selectedUID != selectedUID || self.activeVoices != activeVoices
        self.enabled = enabled; self.selectedUID = selectedUID; self.activeVoices = activeVoices
        if changed { failures = 0; intent = nil; state.error = nil }
        // A deliberate press/release is immediate; retries and preemption storms remain rate-limited.
        if boundary { nextWrite = 0 }
        refresh()
    }

    public func retry() {
        guard !stopped else { return }
        failures = 0; intent = nil; state.error = nil
        if running { refresh() } else { start() }
    }

    public var canSelectInput: Bool {
        running && !stopped && activeVoices.isEmpty && !policy.hasSession && pending == nil && userSelection == nil
    }

    /// Explicit menu action, separate from automatic ownership. Never guesses a stale source UID.
    public func selectInput(uid: String) {
        guard canSelectInput else { return }
        state.selectionError = nil
        do {
            let snapshot = try system.snapshot()
            guard snapshot.inputs.contains(where: { $0.policy.uid == uid }), let source = snapshot.defaultUID else {
                throw InputSystemFailure.unavailable
            }
            guard source != uid else { refresh(); return }
            let request = InputPriorityRequest(sequence: 0, sourceUID: source, targetUID: uid, purpose: .userSelection)
            userSelection = Pending(request: request, deadline: clock() + 1)
            try system.setDefaultInput(request)
        } catch {
            userSelection = nil; state.selectionError = error.localizedDescription
        }
        refresh()
    }

    public func refresh() {
        guard running, !stopped else { return }
        guard !refreshing else { refreshAgain = true; return }
        refreshing = true; nextWakeup = nil
        var fresh: SystemInputSnapshot?
        defer {
            refreshing = false
            if refreshAgain { refreshAgain = false; wake(at: clock() + 0.05) }
            state.pending = pending != nil
            state.selectingInput = userSelection != nil
            state.ownsInput = policy.confirmedVirtualUID != nil
            state.readyForVoice = fresh.map { snapshot in
                enabled && !activeVoices.isEmpty && pending == nil && policy.restoreInputUID != nil
                    && snapshot.defaultUID == selectedUID
                    && snapshot.inputs.contains { $0.policy.uid == selectedUID && $0.policy.supportsPriority }
            } ?? false
            if let fresh {
                state.inputs = fresh.inputs
                state.defaultUID = fresh.defaultUID
                state.restoreInput = fresh.name(for: policy.restorationTarget(in: fresh.inputs.map(\.policy))?.uid)
                state.usingFallback = policy.restoreInputUID != nil && fresh.name(for: policy.restoreInputUID) == nil && state.restoreInput != nil
            }
            onUpdate?()
        }
        let now = clock()
        do {
            let snapshot = try system.snapshot()
            fresh = snapshot
            let observed = observation(snapshot)
            observe(snapshot, observed)
            if let selection = userSelection {
                if snapshot.defaultUID == selection.request.targetUID {
                    userSelection = nil; state.selectionError = nil
                } else if now >= selection.deadline {
                    userSelection = nil; state.selectionError = "系统未确认声音输入切换，请重试。"
                } else {
                    wake(at: min(selection.deadline, now + 0.1)); return
                }
            }
            if let active = pending {
                if snapshot.defaultUID == active.request.targetUID {
                    finish(active.request, snapshot: snapshot)
                } else if now >= active.deadline {
                    policy.reject(active.request); pending = nil
                    fail("系统未在 1 秒内确认默认输入切换。", now: now)
                } else {
                    state.phase = active.request.purpose == .restore ? .restoring : .requesting
                    wake(at: min(active.deadline, now + 0.1)); return
                }
            }
            guard let request = policy.reconcile(observed) else {
                failures = 0; intent = nil; state.error = nil
                if policy.hasSession && activeVoices.isEmpty {
                    state.phase = .noFallback
                } else if let owned = policy.confirmedVirtualUID, snapshot.defaultUID == owned {
                    state.phase = enabled && !activeVoices.isEmpty && selectedUID == owned ? .maintaining : .noFallback
                } else if !enabled { state.phase = .disabled }
                else if activeVoices.isEmpty || policy.restoreInputUID == nil || !snapshot.inputs.contains(where: { $0.policy.uid == selectedUID && $0.policy.supportsPriority }) { state.phase = .waiting }
                else { state.phase = .unchanged }
                return
            }
            let nextIntent = Intent(request)
            if intent != nextIntent { intent = nextIntent; failures = 0; state.error = nil }
            guard failures < 3 else { policy.reject(request); state.phase = .paused; return }
            state.phase = request.purpose == .restore ? .restoring : .requesting
            guard now >= nextWrite else { policy.reject(request); wake(at: nextWrite); return }
            state.requestedInput = snapshot.name(for: request.targetUID)
            nextWrite = now + 0.5
            pending = Pending(request: request, deadline: now + 1)
            do {
                try system.setDefaultInput(request)
            } catch InputSystemFailure.defaultChanged {
                policy.reject(request); pending = nil; state.error = InputSystemFailure.defaultChanged.localizedDescription
                wake(at: nextWrite); return
            } catch {
                policy.reject(request); pending = nil; fail(error.localizedDescription, now: now); return
            }
            // noErr is insufficient: the driver may accept a request without applying it yet.
            let readback = try system.snapshot()
            fresh = readback
            observe(readback, observation(readback))
            if readback.defaultUID == request.targetUID {
                finish(request, snapshot: readback)
                state.phase = request.purpose == .restore ? (enabled ? .waiting : .disabled) : .maintaining
            } else { wake(at: min(now + 0.1, pending!.deadline)) }
        } catch {
            fresh = nil
            state.inputs = []; state.defaultUID = nil
            state.observedInput = nil
            // Keep pending evidence until the deadline; a transient read failure must not invent success.
            state.phase = .failed; state.error = error.localizedDescription
            if let pending, now >= pending.deadline {
                policy.reject(pending.request); self.pending = nil
                fail(error.localizedDescription, now: now)
            } else { wake(at: now + (pending == nil && userSelection == nil ? 2 : 0.1)) }
            if let selection = userSelection, now >= selection.deadline {
                userSelection = nil; state.selectionError = error.localizedDescription
            }
        }
    }

    /// Called after bounded graceful restoration (or as last-resort synchronous teardown).
    public func stop() {
        guard !stopped else { return }
        stopped = true; running = false; nextWakeup = nil
        if let pending { policy.reject(pending.request) }
        pending = nil; userSelection = nil; system.stop()
        state.selectingInput = false
        state.pending = false; state.phase = .stopped
        state.readyForVoice = false
        onUpdate?(); onUpdate = nil
    }

    private func observation(_ snapshot: SystemInputSnapshot) -> InputPriorityObservation {
        InputPriorityObservation(enabled: enabled, activeVoiceIDs: activeVoices, selectedVirtualUID: selectedUID, defaultInputUID: snapshot.defaultUID, availableInputs: snapshot.inputs.map(\.policy))
    }
    private func observe(_ snapshot: SystemInputSnapshot, _ observation: InputPriorityObservation) {
        policy.record(observation)
        state.observedInput = snapshot.name(for: snapshot.defaultUID)
        state.restoreInput = snapshot.name(for: policy.restorationTarget(in: snapshot.inputs.map(\.policy))?.uid)
    }
    private func finish(_ request: InputPriorityRequest, snapshot: SystemInputSnapshot) {
        if policy.confirm(request, observedUID: snapshot.defaultUID) {
            state.confirmedInput = snapshot.name(for: request.targetUID)
            state.error = nil; failures = 0; intent = nil
            if request.purpose == .restore && activeVoices.isEmpty && policy.hasSession { nextWrite = clock() }
        }
        pending = nil
    }
    private func fail(_ message: String, now: TimeInterval) {
        failures += 1; state.error = message
        state.phase = failures >= 3 ? .paused : .failed
        if failures < 3 { wake(at: max(nextWrite, now + 0.1)) }
    }
    private func wake(at value: TimeInterval) { nextWakeup = min(nextWakeup ?? value, value) }
}
