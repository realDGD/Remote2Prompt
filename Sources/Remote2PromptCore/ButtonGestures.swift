/// Deterministic gesture recognition. Times use a monotonic clock supplied by the runtime.
public struct ButtonGestures: Sendable {
    public static let doubleClickDelay = 0.30
    public static let longPressDelay = 0.55
    public static let repeatDelay = 0.45
    public static let repeatInterval = 0.08

    private struct Key: Hashable, Sendable { let owner: String; let button: RemoteButton }
    private struct State: Sendable {
        var down = true
        var secondPress = false
        var longFired = false
        var deadline: Double?
        let click: MappedInvocation
        let double: MappedInvocation
        let long: MappedInvocation
        var immediate: Bool { double.action == .none && long.action == .none }
    }
    private var states: [Key: State] = [:]
    public init() {}

    public mutating func handle(
        owner: String, button: RemoteButton, isDown: Bool, at time: Double, configuration: AppConfiguration
    ) -> [MappedInvocation] {
        var output = advance(to: time)
        let key = Key(owner: owner, button: button)
        if isDown {
            if var state = states[key] {
                guard !state.down else { return output }
                state.down = true
                state.secondPress = true
                state.deadline = state.long.action == .none ? nil : time + Self.longPressDelay
                states[key] = state
            } else {
                var state = State(
                    click: configuration.invocation(for: button, gesture: .click),
                    double: configuration.invocation(for: button, gesture: .doubleClick),
                    long: configuration.invocation(for: button, gesture: .longPress)
                )
                if state.immediate {
                    output.append(state.click)
                    state.deadline = state.click.allowsRepeat ? time + Self.repeatDelay : nil
                } else if state.long.action != .none {
                    state.deadline = time + Self.longPressDelay
                }
                states[key] = state
            }
        } else if var state = states[key], state.down {
            if state.immediate || state.longFired {
                states.removeValue(forKey: key)
            } else if state.secondPress {
                output.append(state.double)
                states.removeValue(forKey: key)
            } else if state.double.action != .none {
                state.down = false
                state.deadline = time + Self.doubleClickDelay
                states[key] = state
            } else {
                output.append(state.click)
                states.removeValue(forKey: key)
            }
        }
        return output.filter { $0.action != .none }
    }

    public mutating func advance(to time: Double) -> [MappedInvocation] {
        var output: [MappedInvocation] = []
        for key in states.keys.sorted(by: { ($0.owner, $0.button.rawValue) < ($1.owner, $1.button.rawValue) }) {
            guard var state = states[key], let deadline = state.deadline, time >= deadline else { continue }
            if !state.down {
                output.append(state.click)
                states.removeValue(forKey: key)
            } else if state.immediate {
                output.append(state.click)
                // A delayed timer must not replay a backlog of actions after sleep or a stalled run loop.
                state.deadline = time + Self.repeatInterval
                states[key] = state
            } else {
                state.longFired = true
                state.deadline = nil
                output.append(state.long)
                states[key] = state
            }
        }
        return output.filter { $0.action != .none }
    }

    public mutating func cancel(owner: String) { states = states.filter { $0.key.owner != owner } }
    public mutating func cancelAll() { states.removeAll() }
}
