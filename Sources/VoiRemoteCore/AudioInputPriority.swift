public struct AudioInput: Equatable, Sendable {
    public enum Kind: Sendable { case physical, virtual, unknown }
    public let uid: String
    public let kind: Kind
    public let supportsPriority: Bool
    public var isVirtual: Bool { kind == .virtual }
    public var isPhysical: Bool { kind == .physical }

    /// Convenience for fixed policy fixtures. System adapters must classify positively.
    public init(uid: String, isVirtual: Bool) {
        self.init(uid: uid, kind: isVirtual ? .virtual : .physical, supportsPriority: isVirtual)
    }
    public init(uid: String, kind: Kind, supportsPriority: Bool = false) {
        self.uid = uid; self.kind = kind; self.supportsPriority = supportsPriority && kind == .virtual
    }
}

public struct InputPriorityRequest: Equatable, Sendable {
    public enum Purpose: Sendable { case prioritize, restore, userSelection }
    public let sequence: UInt64
    public let sourceUID: String
    public let targetUID: String
    public let purpose: Purpose
    public init(sequence: UInt64, sourceUID: String, targetUID: String, purpose: Purpose) {
        self.sequence = sequence; self.sourceUID = sourceUID; self.targetUID = targetUID; self.purpose = purpose
    }
}

/// A fresh observation of CoreAudio and active voice sessions. Runtime AudioDeviceIDs must stay in the adapter.
public struct InputPriorityObservation: Sendable {
    public var enabled: Bool
    public var activeVoiceIDs: Set<String>
    public var selectedVirtualUID: String?
    public var defaultInputUID: String?
    public var availableInputs: [AudioInput]

    public init(
        enabled: Bool,
        activeVoiceIDs: Set<String>,
        selectedVirtualUID: String?,
        defaultInputUID: String?,
        availableInputs: [AudioInput]
    ) {
        self.enabled = enabled
        self.activeVoiceIDs = activeVoiceIDs
        self.selectedVirtualUID = selectedVirtualUID
        self.defaultInputUID = defaultInputUID
        self.availableInputs = availableInputs
    }
}

/// A press-to-use transaction. The pre-press input is immutable until restoration completes.
public struct AudioInputPriority: Sendable {
    public private(set) var restoreInputUID: String?
    public private(set) var confirmedVirtualUID: String?
    public private(set) var hasSession = false
    private var active = false
    private var established = false
    private var releaseObservedUID: String?
    private var idleChoiceUID: String?
    private var lastObservedUID: String?
    private var lastConfirmedUID: String?
    private var sequence: UInt64 = 0
    private var proposal: InputPriorityRequest?

    public init() {}

    public mutating func record(_ observation: InputPriorityObservation) {
        let nowActive = observation.enabled && !observation.activeVoiceIDs.isEmpty
        if nowActive && !hasSession {
            hasSession = true
            // A missing initial default cannot safely become a transaction with no return address.
            restoreInputUID = observation.availableInputs.first { $0.uid == observation.defaultInputUID }?.uid
        }
        if nowActive && !active, let idleChoiceUID {
            // A real system choice after release belongs to the next press, unlike our temporary input.
            restoreInputUID = idleChoiceUID; self.idleChoiceUID = nil
        }
        if !active && !nowActive && hasSession,
           let current = observation.defaultInputUID, current != lastObservedUID,
           current != proposal?.targetUID, current != lastConfirmedUID,
           observation.availableInputs.contains(where: { $0.uid == current }) {
            idleChoiceUID = current
        }
        if active && !nowActive { releaseObservedUID = observation.defaultInputUID }
        active = nowActive
        lastObservedUID = observation.defaultInputUID
    }

    public func restorationTarget(in inputs: [AudioInput]) -> AudioInput? {
        guard hasSession, let saved = idleChoiceUID ?? restoreInputUID else { return nil }
        return inputs.first { $0.uid == saved } ?? inputs.filter(\.isPhysical).sorted { $0.uid < $1.uid }.first
    }

    public mutating func reconcile(_ observation: InputPriorityObservation) -> InputPriorityRequest? {
        record(observation)
        proposal = nil
        let inputs = observation.availableInputs
        if !active && hasSession && !established { clear(); return nil }
        guard let current = observation.defaultInputUID else { return nil }

        if active {
            guard restoreInputUID != nil,
                  let selected = inputs.first(where: { $0.uid == observation.selectedVirtualUID && $0.supportsPriority }) else { return nil }
            if current == selected.uid { established = true; return nil }
            return request(from: current, to: selected.uid, purpose: .prioritize)
        }

        guard hasSession else { return nil }
        if current == (idleChoiceUID ?? restoreInputUID) { clear(); return nil }
        // A choice made *after* release ends the transaction; idle input selection belongs to macOS.
        // A late confirmation of our accepted write is still eligible for restoration.
        guard current == releaseObservedUID || current == confirmedVirtualUID || current == lastConfirmedUID else { clear(); return nil }
        guard let restore = restorationTarget(in: inputs) else { return nil }
        if current == restore.uid { clear(); return nil }
        return request(from: current, to: restore.uid, purpose: .restore)
    }

    @discardableResult
    public mutating func confirm(_ request: InputPriorityRequest, observedUID: String?) -> Bool {
        guard proposal == request, observedUID == request.targetUID else { return false }
        lastConfirmedUID = request.targetUID
        switch request.purpose {
        case .userSelection: return false
        case .prioritize:
            confirmedVirtualUID = request.targetUID; established = true
        case .restore:
            confirmedVirtualUID = nil
            if !active && (idleChoiceUID == nil || idleChoiceUID == observedUID) { clear() }
        }
        proposal = nil
        return true
    }

    public mutating func reject(_ request: InputPriorityRequest) {
        if proposal == request { proposal = nil }
    }

    private mutating func clear() {
        hasSession = false; established = false; restoreInputUID = nil
        confirmedVirtualUID = nil; releaseObservedUID = nil; proposal = nil
        idleChoiceUID = nil; lastConfirmedUID = nil
    }

    private mutating func request(from source: String, to target: String, purpose: InputPriorityRequest.Purpose) -> InputPriorityRequest {
        sequence &+= 1
        let value = InputPriorityRequest(sequence: sequence, sourceUID: source, targetUID: target, purpose: purpose)
        proposal = value
        return value
    }
}
