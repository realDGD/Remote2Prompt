import Remote2PromptCore

func voiceInputSnapshotChecks() -> [(String, () throws -> Void)] {
    [
        ("idle changes do not capture a restore target or write input", {
            var policy = AudioInputPriority()
            for current in ["built-in", "airpods", "virtual"] {
                try expect(policy.reconcile(observation(remotes: [], current: current)) == nil, "Idle input was changed")
                try expect(!policy.hasSession && policy.restoreInputUID == nil, "Idle input became a transaction")
            }
        }),
        ("each completed press captures the current system input afresh", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "virtual")) == "built-in", "First press did not restore")
            _ = policy.simulateSuccessfulSwitch(observation(current: "airpods"))
            try expect(policy.restoreInputUID == "airpods", "Second press reused the old snapshot")
            try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "virtual")) == "airpods", "Second press restored the wrong input")
        }),
        ("the exact original virtual or unknown input can be restored", {
            for kind in [AudioInput.Kind.virtual, .unknown] {
                var policy = AudioInputPriority()
                let inputs = [AudioInput(uid: "original", kind: kind), AudioInput(uid: "virtual", isVirtual: true)]
                try expect(policy.simulateSuccessfulSwitch(observation(current: "original", inputs: inputs)) == "virtual", "Original nonphysical input could not be captured")
                try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "virtual", inputs: inputs)) == "original", "Exact original input was replaced by a physical fallback")
            }
        }),
        ("an external choice made during the hold does not replace the snapshot", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            let restore = policy.reconcile(observation(remotes: [], current: "airpods"))
            try expect(restore?.targetUID == "built-in" && restore?.purpose == .restore, "Release adopted an input selected during the hold")
        }),
        ("a post-release choice ends restoration retries", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            let restore = policy.reconcile(observation(remotes: [], current: "virtual"))!
            policy.reject(restore)
            try expect(policy.reconcile(observation(remotes: [], current: "airpods")) == nil, "Idle system selection was overridden")
            try expect(!policy.hasSession, "Idle transaction remained active")
        }),
        ("rapid re-press retains the original baseline until restoration settles", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            let restore = policy.reconcile(observation(remotes: [], current: "virtual"))!
            policy.reject(restore)
            try expect(policy.reconcile(observation(current: "virtual")) == nil, "Re-press rewrote an already selected input")
            try expect(policy.restoreInputUID == "built-in", "Temporary loopback became the new baseline")
            try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "virtual")) == "built-in", "Re-press lost the return input")
        }),
        ("a missing pre-press snapshot prevents takeover", {
            var policy = AudioInputPriority()
            try expect(policy.reconcile(observation(current: nil)) == nil, "Missing default produced a write")
            try expect(policy.reconcile(observation(current: "built-in")) == nil, "A later observation silently replaced the missing pre-press snapshot")
        }),
        ("an already selected loopback remains the exact release target", {
            var policy = AudioInputPriority()
            try expect(policy.reconcile(observation(current: "virtual")) == nil, "Existing input was rewritten")
            let restore = policy.reconcile(observation(remotes: [], current: "airpods"))!
            try expect(restore.targetUID == "virtual" && restore.purpose == .restore, "The original loopback was replaced by a physical device")
            try expect(policy.confirm(restore, observedUID: "virtual") && !policy.hasSession, "Exact original virtual input did not complete restoration")
        }),
        ("a re-press during delayed restoration keeps the baseline", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            let restoring = policy.reconcile(observation(remotes: [], current: "virtual"))!
            policy.record(observation(current: "virtual"))
            try expect(policy.confirm(restoring, observedUID: "built-in"), "Pending restore could not confirm")
            try expect(policy.hasSession && policy.restoreInputUID == "built-in", "A delayed restore erased the new held session")
            try expect(policy.simulateSuccessfulSwitch(observation(current: "built-in")) == "virtual", "New held session did not reacquire the loopback")
        }),
        ("an idle system choice survives a late accepted takeover", {
            var policy = AudioInputPriority()
            let pending = policy.reconcile(observation())!
            policy.record(observation(remotes: [], current: "built-in"))
            policy.record(observation(remotes: [], current: "airpods"))
            try expect(policy.confirm(pending, observedUID: "virtual"), "Late takeover could not be tracked")
            try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "virtual")) == "airpods", "Late takeover overwrote a post-release system choice")
        }),
        ("an idle system choice is recovered after a delayed restore", {
            var policy = AudioInputPriority()
            _ = policy.simulateSuccessfulSwitch(observation())
            let pending = policy.reconcile(observation(remotes: [], current: "virtual"))!
            policy.record(observation(remotes: [], current: "airpods"))
            try expect(policy.confirm(pending, observedUID: "built-in") && policy.hasSession, "Delayed restore erased the later system choice")
            try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "built-in")) == "airpods", "Late restore permanently replaced the idle choice")
        })
    ]
}
