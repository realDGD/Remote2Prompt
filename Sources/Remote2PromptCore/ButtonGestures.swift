/// Deterministic gesture recognition. Times use a monotonic clock supplied by the runtime.
public struct ButtonGestures: Sendable {
    // Kept as the default timing API; each gesture snapshots its configured timing.
    public static let doubleClickDelay = 0.30
    public static let longPressDelay = 0.55
    public static let repeatDelay = 0.45
    public static let repeatInterval = 0.08

    private struct Key: Hashable, Sendable { let owner: String; let button: RemoteButton }
    private enum Deadline: Sendable { case clickTimeout, longPress, clickHold, repeatAction }
    private struct State: Sendable {
        var down = true
        var secondPress = false
        var committed: ButtonGesture?
        var deadline: Double?
        var deadlineKind: Deadline?
        let click: MappedInvocation
        let double: MappedInvocation
        let long: MappedInvocation
        let timing: GestureTiming
        let behavior: ButtonBehavior
        var hasSecondary: Bool { double.action != .none || long.action != .none }
        var repeatsClick: Bool {
            switch behavior.clickRepeat {
            case .automatic: click.allowsRepeat
            case .disabled: false
            case .enabled: true
            }
        }
        func invocation(_ gesture: ButtonGesture) -> MappedInvocation {
            switch gesture { case .click: click; case .doubleClick: double; case .longPress: long }
        }
        mutating func schedule(_ kind: Deadline, at time: Double) { deadlineKind = kind; deadline = time }
        mutating func clearDeadline() { deadlineKind = nil; deadline = nil }
    }
    private var states: [Key: State] = [:]
    public init() {}

    public mutating func handle(
        owner: String, button: RemoteButton, isDown: Bool, at time: Double, configuration: AppConfiguration
    ) -> [MappedInvocation] {
        guard time.isFinite, configuration.gestureTiming.isValid else { return [] }
        var output = advance(to: time)
        let key = Key(owner: owner, button: button)
        if isDown {
            if var state = states[key] {
                guard !state.down else { return output }
                state.down = true; state.secondPress = true; state.clearDeadline()
                if state.behavior.doubleClickHoldRepeats {
                    // This explicit mode commits on the second down; release never duplicates it.
                    state.committed = .doubleClick
                    output.append(state.double)
                    state.schedule(.repeatAction, at: time + state.timing.repeatDelay)
                } else if state.long.action != .none {
                    state.schedule(.longPress, at: time + state.timing.longPressDelay)
                }
                states[key] = state
            } else {
                var state = State(
                    click: configuration.invocation(for: button, gesture: .click),
                    double: configuration.invocation(for: button, gesture: .doubleClick),
                    long: configuration.invocation(for: button, gesture: .longPress),
                    timing: configuration.gestureTiming, behavior: configuration.behavior(for: button)
                )
                if !state.hasSecondary {
                    state.committed = .click; output.append(state.click)
                    if state.repeatsClick && state.click.action != .none {
                        state.schedule(.repeatAction, at: time + state.timing.repeatDelay)
                    }
                } else if state.long.action != .none {
                    // Never send a single action before resolving an explicitly mapped long press.
                    state.schedule(.longPress, at: time + state.timing.longPressDelay)
                } else if state.behavior.clickRepeat == .enabled && state.click.action != .none {
                    // With only double-click mapped, an explicitly held first press may commit to single repeat.
                    state.schedule(.clickHold, at: time + state.timing.repeatDelay)
                }
                states[key] = state
            }
        } else if var state = states[key], state.down {
            if state.committed != nil {
                states.removeValue(forKey: key)
            } else if state.secondPress {
                output.append(state.double); states.removeValue(forKey: key)
            } else if state.double.action != .none {
                state.down = false
                state.schedule(.clickTimeout, at: time + state.timing.doubleClickDelay)
                states[key] = state
            } else {
                output.append(state.click); states.removeValue(forKey: key)
            }
        }
        return output.filter { $0.action != .none }
    }

    public mutating func advance(to time: Double) -> [MappedInvocation] {
        guard time.isFinite else { return [] }
        var output: [MappedInvocation] = []
        for key in states.keys.sorted(by: { ($0.owner, $0.button.rawValue) < ($1.owner, $1.button.rawValue) }) {
            guard var state = states[key], let deadline = state.deadline, time >= deadline, let kind = state.deadlineKind else { continue }
            switch kind {
            case .clickTimeout:
                output.append(state.click); states.removeValue(forKey: key); continue
            case .longPress:
                state.committed = .longPress; output.append(state.long)
                state.clearDeadline()
                if state.behavior.longPressRepeats {
                    state.schedule(.repeatAction, at: time + state.timing.repeatInterval)
                }
            case .clickHold:
                state.committed = .click; output.append(state.click)
                state.schedule(.repeatAction, at: time + state.timing.repeatInterval)
            case .repeatAction:
                if let committed = state.committed { output.append(state.invocation(committed)) }
                // A stalled timer never replays a backlog, regardless of the chosen gesture.
                state.schedule(.repeatAction, at: time + state.timing.repeatInterval)
            }
            states[key] = state
        }
        return output.filter { $0.action != .none }
    }

    public mutating func cancel(owner: String) { states = states.filter { $0.key.owner != owner } }
    public mutating func cancelAll() { states.removeAll() }
}
