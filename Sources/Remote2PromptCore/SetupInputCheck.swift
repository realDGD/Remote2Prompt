/// Ephemeral evidence from one remote and one setup attempt. Never persisted as hardware success.
public struct SetupInputCheck: Equatable, Sendable {
    public enum Stage: Sendable { case idle, buttons, voice }
    public private(set) var stage: Stage = .idle
    public private(set) var buttons: Set<RemoteButton> = []
    public private(set) var voicePressed = false
    public private(set) var voiceReleased = false
    private var owner: String?
    private var pendingButtons: Set<RemoteButton> = []
    private var pendingVoice = false

    public init() {}
    public var buttonsComplete: Bool { buttons.count >= 2 }
    public var complete: Bool { buttonsComplete && voicePressed && voiceReleased }

    public mutating func beginButtons() {
        self = Self()
        stage = .buttons
    }

    public mutating func beginVoice() {
        guard buttonsComplete else { return }
        stage = .voice
        voicePressed = false; voiceReleased = false; pendingVoice = false
    }

    public mutating func receive(owner source: String, previous: Set<UInt16>, current: Set<UInt16>) {
        guard stage != .idle else { return }
        let down = current.subtracting(previous)
        let up = previous.subtracting(current)
        if owner == nil && stage == .buttons && down.contains(where: { XiaomiRemote.buttonUsages[$0] != nil }) {
            owner = source
        }
        guard owner == source else { return }
        switch stage {
        case .idle: break
        case .buttons:
            for usage in down {
                if let button = XiaomiRemote.buttonUsages[usage] { pendingButtons.insert(button) }
            }
            for usage in up {
                if let button = XiaomiRemote.buttonUsages[usage], pendingButtons.remove(button) != nil { buttons.insert(button) }
            }
        case .voice:
            if down.contains(XiaomiRemote.voiceUsage) {
                pendingVoice = true; voicePressed = true; voiceReleased = false
            }
            if up.contains(XiaomiRemote.voiceUsage) && pendingVoice {
                pendingVoice = false; voiceReleased = true
            }
        }
    }

    public mutating func disconnected(owner source: String) {
        if owner == source { invalidate() }
    }

    public mutating func invalidate() { self = Self() }
}
