public struct AudioInput: Equatable, Sendable {
    public let uid: String
    public let isVirtual: Bool

    public init(uid: String, isVirtual: Bool) {
        self.uid = uid
        self.isVirtual = isVirtual
    }
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

/// Issue #435 policy. Returns a requested UID; a later adapter owns writes, errors, and observation feedback.
public struct AudioInputPriority: Sendable {
    public private(set) var recentPhysicalInputUID: String?
    private var prioritizedVirtualUID: String?

    public init() {}

    public mutating func reconcile(_ observation: InputPriorityObservation) -> String? {
        let inputs = observation.availableInputs
        if let current = inputs.first(where: { $0.uid == observation.defaultInputUID }), !current.isVirtual {
            recentPhysicalInputUID = current.uid
        }

        if observation.enabled, !observation.readyRemoteIDs.isEmpty,
           let selected = inputs.first(where: { $0.uid == observation.selectedVirtualUID && $0.isVirtual }) {
            prioritizedVirtualUID = selected.uid
            return observation.defaultInputUID == selected.uid ? nil : selected.uid
        }

        // Do not undo an unrelated manual choice, or restore to an unavailable device.
        let previousVirtual = prioritizedVirtualUID
        prioritizedVirtualUID = nil
        guard previousVirtual != nil, observation.defaultInputUID == previousVirtual else { return nil }
        return inputs.first(where: { $0.uid == recentPhysicalInputUID && !$0.isVirtual })?.uid
            ?? inputs.first(where: { !$0.isVirtual })?.uid
    }
}
