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
    public enum Purpose: Sendable { case prioritize, restore }
    public let sequence: UInt64
    public let sourceUID: String
    public let targetUID: String
    public let purpose: Purpose
}

/// A fresh observation of CoreAudio and ready remotes. Runtime AudioDeviceIDs must stay in the adapter.
public struct InputPriorityObservation: Sendable {
    public var enabled: Bool
    public var readyRemoteIDs: Set<String>
    public var selectedVirtualUID: String?
    public var defaultInputUID: String?
    public var availableInputs: [AudioInput]

    public init(
        enabled: Bool,
        readyRemoteIDs: Set<String>,
        selectedVirtualUID: String?,
        defaultInputUID: String?,
        availableInputs: [AudioInput]
    ) {
        self.enabled = enabled
        self.readyRemoteIDs = readyRemoteIDs
        self.selectedVirtualUID = selectedVirtualUID
        self.defaultInputUID = defaultInputUID
        self.availableInputs = availableInputs
    }
}

/// Issue #435 policy. A proposal is not ownership; only accepted writes with matching readback are confirmed.
public struct AudioInputPriority: Sendable {
    public private(set) var recentPhysicalInputUID: String?
    public private(set) var confirmedVirtualUID: String?
    private var sequence: UInt64 = 0
    private var proposal: InputPriorityRequest?

    public init() {}

    public mutating func record(_ observation: InputPriorityObservation) {
        let inputs = observation.availableInputs
        if let current = inputs.first(where: { $0.uid == observation.defaultInputUID }), current.isPhysical {
            recentPhysicalInputUID = current.uid
        }
    }

    public mutating func reconcile(_ observation: InputPriorityObservation) -> InputPriorityRequest? {
        record(observation)
        proposal = nil
        let inputs = observation.availableInputs
        guard let current = observation.defaultInputUID else { return nil }

        if observation.enabled, !observation.readyRemoteIDs.isEmpty,
           let selected = inputs.first(where: { $0.uid == observation.selectedVirtualUID && $0.supportsPriority }) {
            if current == selected.uid {
                if confirmedVirtualUID != selected.uid { confirmedVirtualUID = nil }
                return nil
            }
            return request(from: current, to: selected.uid, purpose: .prioritize)
        }

        guard let owned = confirmedVirtualUID else { return nil }
        // An external choice after shutdown/disable must be preserved, including another virtual input.
        guard current == owned else { confirmedVirtualUID = nil; return nil }
        let physical = inputs.filter(\.isPhysical).sorted { $0.uid < $1.uid }
        guard let restore = physical.first(where: { $0.uid == recentPhysicalInputUID }) ?? physical.first else { return nil }
        return request(from: current, to: restore.uid, purpose: .restore)
    }

    @discardableResult
    public mutating func confirm(_ request: InputPriorityRequest, observedUID: String?) -> Bool {
        guard proposal == request, observedUID == request.targetUID else { return false }
        switch request.purpose {
        case .prioritize: confirmedVirtualUID = request.targetUID
        case .restore:
            guard confirmedVirtualUID == request.sourceUID else { return false }
            confirmedVirtualUID = nil
        }
        proposal = nil
        return true
    }

    public mutating func reject(_ request: InputPriorityRequest) {
        if proposal == request { proposal = nil }
    }

    private mutating func request(from source: String, to target: String, purpose: InputPriorityRequest.Purpose) -> InputPriorityRequest {
        sequence &+= 1
        let value = InputPriorityRequest(sequence: sequence, sourceUID: source, targetUID: target, purpose: purpose)
        proposal = value
        return value
    }
}
