import Foundation
import Remote2PromptCore

struct CheckFailure: Error, CustomStringConvertible {
    let description: String
}

func expect(_ value: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !value() { throw CheckFailure(description: message) }
}

func observation(
    enabled: Bool = true,
    remotes: Set<String> = ["remote-a"],
    selected: String? = "virtual",
    current: String? = "built-in",
    inputs: [AudioInput]? = nil
) -> InputPriorityObservation {
    InputPriorityObservation(
        enabled: enabled,
        activeVoiceIDs: remotes,
        selectedVirtualUID: selected,
        defaultInputUID: current,
        availableInputs: inputs ?? [
            AudioInput(uid: "built-in", isVirtual: false),
            AudioInput(uid: "airpods", isVirtual: false),
            AudioInput(uid: "virtual", isVirtual: true)
        ]
    )
}

var checks: [(String, () throws -> Void)] = [
    ("configuration defaults are opt-in", {
        let config = AppConfiguration()
        try expect(!config.preferVirtualInput && !config.mappingsEnabled, "Opt-in defaults changed")
        try expect(config.voiceTrigger == .function, "Fn must remain the default")
    }),
    ("old configuration gets safe defaults", {
        let config = try AppConfiguration.decode(Data("{}".utf8))
        try expect(config == AppConfiguration(), "Missing fields did not inherit defaults")
    }),
    ("configuration preserves right Control and mapping gestures", {
        var config = AppConfiguration()
        config.voiceTrigger = .rightControl
        config.preferVirtualInput = true
        config.selectedVirtualInputUID = "device-uid"
        config.setAction(.copy, for: .home, gesture: .doubleClick)
        let decoded = try AppConfiguration.decode(config.encoded())
        try expect(decoded == config, "Configuration round trip changed preferences")
        try expect(decoded.action(for: .home, gesture: .click) == .none, "Gestures overlapped")
    }),
    ("mapping replacement and removal are unambiguous", {
        var config = AppConfiguration()
        config.setAction(.copy, for: .home, gesture: .click)
        config.setAction(.paste, for: .home, gesture: .click)
        try expect(config.bindings.count == 1, "Replacement duplicated a binding")
        try expect(config.action(for: .home, gesture: .click) == .paste, "Replacement failed")
        config.setAction(.none, for: .home, gesture: .click)
        try expect(config.bindings.isEmpty, "None must remove the binding")
    }),
    ("future schemas are rejected", {
        do {
            _ = try AppConfiguration.decode(Data("{\"schemaVersion\":99}".utf8))
            throw CheckFailure(description: "Future schema was accepted")
        } catch ConfigurationError.unsupportedVersion(99) {}
    }),
    ("malformed settings are rejected", {
        do {
            _ = try AppConfiguration.decode(Data("{\"preferVirtualInput\":\"yes\"}".utf8))
            throw CheckFailure(description: "Wrong field type was accepted")
        } catch is DecodingError {}
    }),
    ("duplicate persisted bindings are rejected", {
        var config = AppConfiguration()
        let binding = KeyBinding(button: .home, gesture: .click, action: .copy)
        config.bindings = [binding, binding]
        do {
            _ = try AppConfiguration.decode(config.encoded())
            throw CheckFailure(description: "Duplicate bindings were accepted")
        } catch ConfigurationError.duplicateBinding {}
    }),
    ("priority disabled respects system input", {
        var policy = AudioInputPriority()
        try expect(policy.simulateSuccessfulSwitch(observation(enabled: false)) == nil, "Disabled policy changed input")
    }),
    ("active voice session selects virtual input", {
        var policy = AudioInputPriority()
        try expect(policy.simulateSuccessfulSwitch(observation()) == "virtual", "Virtual input was not requested")
        try expect(policy.simulateSuccessfulSwitch(observation(current: "virtual")) == nil, "Self-notification caused a write loop")
    }),
    ("preemption during voice never replaces the pre-press snapshot", {
        var policy = AudioInputPriority()
        _ = policy.simulateSuccessfulSwitch(observation())
        try expect(policy.simulateSuccessfulSwitch(observation(current: "airpods")) == "virtual", "AirPods stole the input")
        try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "virtual")) == "built-in", "Pre-press input was replaced by a later device")
        try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "airpods")) == nil, "Restore caused a write loop")
    }),
    ("only the last active voice session restores", {
        var policy = AudioInputPriority()
        _ = policy.simulateSuccessfulSwitch(observation(remotes: ["remote-a", "remote-b"]))
        try expect(policy.simulateSuccessfulSwitch(observation(remotes: ["remote-b"], current: "virtual")) == nil, "An active remote lost priority")
        try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "virtual")) == "built-in", "Last disconnect did not restore")
    }),
    ("disabling active priority restores physical input", {
        var policy = AudioInputPriority()
        _ = policy.simulateSuccessfulSwitch(observation())
        try expect(policy.simulateSuccessfulSwitch(observation(enabled: false, current: "virtual")) == "built-in", "Disabling failed to restore")
    }),
    ("manual choice after disconnect is preserved", {
        var policy = AudioInputPriority()
        _ = policy.simulateSuccessfulSwitch(observation())
        _ = policy.reconcile(observation(remotes: [], current: "virtual"))
        try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "airpods")) == nil, "Post-release input selection was overwritten")
    }),
    ("missing virtual device never selects a physical device as virtual", {
        var policy = AudioInputPriority()
        try expect(policy.simulateSuccessfulSwitch(observation(selected: "missing")) == nil, "Missing device produced a switch")
        try expect(policy.simulateSuccessfulSwitch(observation(selected: "built-in")) == nil, "Physical device was treated as virtual")
    }),
    ("removed restore device falls back to available physical input", {
        var policy = AudioInputPriority()
        _ = policy.simulateSuccessfulSwitch(observation(current: "airpods"))
        let inputs = [AudioInput(uid: "built-in", isVirtual: false), AudioInput(uid: "virtual", isVirtual: true)]
        try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "virtual", inputs: inputs)) == "built-in", "Unavailable fallback was requested")
    }),
    ("no physical fallback leaves the default alone", {
        var policy = AudioInputPriority()
        _ = policy.simulateSuccessfulSwitch(observation())
        let inputs = [AudioInput(uid: "virtual", isVirtual: true)]
        try expect(policy.simulateSuccessfulSwitch(observation(remotes: [], current: "virtual", inputs: inputs)) == nil, "Policy invented a fallback")
    }),
    ("empty device snapshots are harmless", {
        var policy = AudioInputPriority()
        try expect(policy.simulateSuccessfulSwitch(observation(current: nil, inputs: [])) == nil, "Empty device list produced a write")
    }),
    ("left and right Control use distinct macOS keycodes", {
        try expect(VoiceTrigger.leftControl.virtualKeyCode == 59, "Left Control keycode changed")
        try expect(VoiceTrigger.rightControl.virtualKeyCode == 62, "Right Control keycode changed")
    }),
    ("every voice trigger produces a matching release", {
        for trigger in VoiceTrigger.allCases {
            var session = VoiceSession()
            let start = session.begin(owner: "a", trigger: trigger)
            let end = session.end(owner: "a")
            try expect(start.count == 1 && start.first?.isDown == true, "Missing keyDown")
            try expect(end.count == 1 && end.first?.isDown == false, "Missing keyUp")
            try expect(start.first?.trigger == end.first?.trigger, "Released a different key")
        }
    }),
    ("duplicate begin and end are idempotent", {
        var session = VoiceSession()
        _ = session.begin(owner: "a", trigger: .leftControl)
        try expect(session.begin(owner: "a", trigger: .leftControl).isEmpty, "Duplicate keyDown")
        _ = session.end(owner: "a")
        try expect(session.end(owner: "a").isEmpty, "Duplicate keyUp")
    }),
    ("overlapping remotes keep the first key latched", {
        var session = VoiceSession()
        _ = session.begin(owner: "a", trigger: .rightControl)
        try expect(session.begin(owner: "b", trigger: .leftCommand).isEmpty, "Second remote changed the held key")
        try expect(session.end(owner: "a").isEmpty, "Key released while another remote was speaking")
        try expect(session.end(owner: "unknown").isEmpty, "Unknown remote released the key")
        try expect(session.end(owner: "b").first?.trigger == .rightControl, "Settings change altered the release key")
    }),
    ("shutdown releases once and clears owners", {
        var session = VoiceSession()
        _ = session.begin(owner: "a", trigger: .rightControl)
        try expect(session.cancelAll().first?.isDown == false, "Shutdown did not release")
        try expect(session.cancelAll().isEmpty, "Shutdown emitted a second release")
        try expect(session.begin(owner: "a", trigger: .leftControl).first?.isDown == true, "Cancelled owner could not restart")
    })
]
// Keep each inference boundary explicit for standalone CLT's Swift 6.1 compiler.
checks.append(contentsOf: mappingChecks())
checks.append(contentsOf: gestureOptionChecks())
checks.append(contentsOf: advancedGestureChecks())
checks.append(contentsOf: commonMappingChecks() + freshVoicePressChecks() + voiceLimitIndicatorChecks())
checks.append(contentsOf: setupChecks())
checks.append(contentsOf: voiceProtocolChecks())
checks.append(contentsOf: voiceReminderPlacementChecks())
checks.append(contentsOf: playoutClockChecks())
checks.append(contentsOf: inputPriorityChecks())
checks.append(contentsOf: voiceInputSnapshotChecks())
checks.append(contentsOf: configurationTransferChecks())

var failed = 0
for (name, check) in checks {
    do {
        try check()
        print("PASS \(name)")
    } catch {
        failed += 1
        print("FAIL \(name): \(error)")
    }
}
print("\(checks.count - failed)/\(checks.count) checks passed")
if failed != 0 { exit(1) }
