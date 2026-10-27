import Remote2PromptCore

extension AudioInputPriority {
    /// The original policy scenarios explicitly simulate an adapter that applies and reads back every request.
    mutating func simulateSuccessfulSwitch(_ value: InputPriorityObservation) -> String? {
        guard let request = reconcile(value) else { return nil }
        _ = confirm(request, observedUID: request.targetUID)
        return request.targetUID
    }
}

func inputPriorityChecks() -> [(String, () throws -> Void)] {
    [
        ("priority proposals do not acquire restoration ownership", {
            var policy = AudioInputPriority()
            let request = policy.reconcile(observation())!
            try expect(request.sourceUID == "built-in" && request.targetUID == "virtual" && request.purpose == .prioritize, "Request lost its precondition")
            try expect(policy.confirmedVirtualUID == nil, "Unconfirmed request acquired ownership")
            try expect(!policy.confirm(request, observedUID: "built-in"), "Mismatched readback confirmed")
            policy.reject(request)
            try expect(!policy.confirm(request, observedUID: "virtual"), "Rejected request later acquired ownership")
            try expect(policy.reconcile(observation(enabled: false, current: "virtual")) == nil, "Failed request restored an unowned virtual input")
        }),
        ("initial user-selected virtual input remains unowned", {
            var policy = AudioInputPriority()
            try expect(policy.reconcile(observation(current: "virtual")) == nil, "Already selected input was rewritten")
            try expect(policy.reconcile(observation(enabled: false, current: "virtual")) == nil, "Existing virtual choice was undone")
        }),
        ("failed restore retains ownership for bounded adapter retry", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            let off = observation(enabled: false, current: "virtual")
            let first = policy.reconcile(off)!
            policy.reject(first)
            try expect(policy.confirmedVirtualUID == "virtual", "Failure discarded the restoration lease")
            let retry = policy.reconcile(off)!
            try expect(retry.purpose == .restore && retry.targetUID == "built-in", "Restoration cannot retry")
            try expect(!policy.confirm(first, observedUID: "built-in"), "Stale confirmation was accepted")
            try expect(policy.confirm(retry, observedUID: "built-in") && policy.confirmedVirtualUID == nil, "Confirmed restoration retained ownership")
        }),
        ("unknown and other software inputs cannot become physical fallback", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            let inputs = [AudioInput(uid: "virtual", isVirtual: true), AudioInput(uid: "unknown", kind: .unknown), AudioInput(uid: "other-loopback", kind: .virtual)]
            try expect(policy.reconcile(observation(enabled: false, current: "virtual", inputs: inputs)) == nil, "Nonphysical fallback selected")
            try expect(policy.reconcile(observation(selected: "other-loopback", inputs: inputs)) == nil, "Unverified loopback was prioritized")
        }),
        ("fallback order is stable and independent of enumeration", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            let inputs = [AudioInput(uid: "z-device", isVirtual: false), AudioInput(uid: "virtual", isVirtual: true), AudioInput(uid: "a-device", isVirtual: false)]
            let request = policy.reconcile(observation(enabled: false, current: "virtual", inputs: inputs))
            try expect(request?.targetUID == "a-device", "Fallback follows unstable enumeration order")
        }),
        ("selection changes transfer only confirmed ownership", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            let inputs = [AudioInput(uid: "built-in", isVirtual: false), AudioInput(uid: "virtual", isVirtual: true), AudioInput(uid: "virtual-b", isVirtual: true)]
            let next = policy.reconcile(observation(selected: "virtual-b", current: "virtual", inputs: inputs))!
            try expect(policy.confirmedVirtualUID == "virtual", "New proposal discarded old ownership")
            try expect(policy.confirm(next, observedUID: "virtual-b"), "Confirmed transfer failed")
            try expect(policy.reconcile(observation(enabled: false, selected: nil, current: "virtual-b", inputs: inputs))?.targetUID == "built-in", "Changed selection lost physical fallback")
        }),
        ("external choice during inactive restoration is preserved", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            _ = policy.reconcile(observation(enabled: false, current: "virtual"))
            try expect(policy.reconcile(observation(enabled: false, current: "airpods")) == nil, "External physical choice was overwritten")
            try expect(policy.confirmedVirtualUID == nil, "Inactive ownership survived external choice")
        })
    ]
}
