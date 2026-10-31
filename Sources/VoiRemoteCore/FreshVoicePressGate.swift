/// After interrupted ownership, each source must report a released voice key before arming it.
/// A held key in the first report after wake must not become a new voice session.
public struct FreshVoicePressGate: Sendable {
    private var needsRelease = false
    private var released: Set<String> = []
    public init() {}
    public mutating func requireRelease() { needsRelease = true; released.removeAll() }
    public mutating func remove(owner: String) { released.remove(owner) }
    public mutating func accepts(owner: String, isDown: Bool) -> Bool {
        guard needsRelease else { return true }
        if !isDown { released.insert(owner) }
        return released.contains(owner)
    }
}
