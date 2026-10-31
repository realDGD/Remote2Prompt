import AppKit
import CoreGraphics
import VoiRemoteCore
import VoiRemoteMac

@MainActor private final class CapsuleSmokeSource: WeTypeWindowSource {
    var snapshot = WeTypeGeometrySnapshot.unavailable
    var reads = 0
    func read(_ completion: @escaping @MainActor @Sendable (WeTypeGeometrySnapshot) -> Void) {
        reads += 1; completion(snapshot)
    }
    func move(to bounds: CGRect) {
        snapshot = WeTypeGeometrySnapshot(version: "3.0.0", windows: [
            WeTypeWindowGeometry(id: 1, bounds: bounds, layer: Int(CGWindowLevelForKey(.maximumWindow)) - 2)
        ])
    }
}

/// Exercises the actual panel using synthetic numeric geometry, never another app or hardware.
@MainActor func smokeCapsuleFollowing() async throws {
    struct Failure: Error { let message: String }
    func require(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure(message: message) }
    }
    guard let screen = NSScreen.screens.first else { throw Failure(message: "No screen") }
    let source = CapsuleSmokeSource()
    let runtime = VoiceLimitReminderRuntime(clock: { 52 })
    let hud = VoiceLimitHUDController(runtime: runtime, inspectionSource: source)
    defer { hud.shutdown() }
    let key = NSApp.keyWindow; let main = NSApp.mainWindow; let active = NSApp.isActive
    var config = AppConfiguration()
    config.voiceEnabled = true; config.remoteAudioEnabled = true; config.voiceLimitReminderEnabled = true
    hud.configure(config)
    var policy = VoiceLimitIndicator(); policy.begin(segment: 1, at: 0, hasRC003Limit: true)
    hud.update(policy)
    try await Task.sleep(for: .milliseconds(250))
    let fixed = hud.inspectionFrame
    try require(fixed?.size == VoiceLimitHUDLayout.size && source.reads > 0, "Missing panel/fallback or inconsistent compact size")

    let appKitBounds = CGRect(x: screen.visibleFrame.midX - 175, y: screen.visibleFrame.midY, width: 350, height: 130)
    let first = CGRect(x: appKitBounds.minX, y: screen.frame.maxY - appKitBounds.maxY, width: 350, height: 130)
    source.move(to: first)
    try await Task.sleep(for: .milliseconds(250))
    let expected = VoiceReminderPlacement.following(topLeftWindow: first, primaryMaxY: screen.frame.maxY,
        screens: NSScreen.screens.map { ReminderScreen(frame: $0.frame, visibleFrame: $0.visibleFrame) }, size: VoiceLimitHUDLayout.size)
        .map { CGPoint(x: $0.x.rounded(), y: $0.y.rounded()) }
    try require(expected != nil && hud.inspectionFrame?.origin == expected && hud.inspectionFrame != fixed, "Panel did not follow geometry")

    let moved = first.offsetBy(dx: 60, dy: -20)
    source.move(to: moved)
    try await Task.sleep(for: .milliseconds(250))
    let followed = hud.inspectionFrame
    try require(followed?.origin != expected, "Moving capsule did not move panel")
    source.move(to: CGRect(x: moved.minX, y: moved.minY - 90, width: moved.width, height: moved.height + 90))
    try await Task.sleep(for: .milliseconds(250))
    try require(hud.inspectionFrame == followed, "Text growth moved stable lower anchor")

    source.snapshot = .unavailable
    try await Task.sleep(for: .milliseconds(250))
    try require(hud.inspectionFrame == fixed, "Missing capsule did not restore fixed position")
    hud.configure(AppConfiguration())
    let count = source.reads
    try await Task.sleep(for: .milliseconds(300))
    try require(hud.previewIsHidden && source.reads == count, "Hidden panel retained queries")
    hud.preview()
    try await Task.sleep(for: .milliseconds(250))
    try require(hud.previewIsNonactivating && source.reads == count && hud.inspectionFrame == fixed, "Preview queried windows or lost fallback")
    try require(NSApp.keyWindow === key && NSApp.mainWindow === main && NSApp.isActive == active, "Geometry updates changed focus")
    hud.shutdown()
    try await Task.sleep(for: .milliseconds(250))
    try require(hud.previewIsHidden && source.reads == count, "Shutdown revived panel/queries")
    print("Synthetic capsule HUD smoke passed: real panel follows/moves, avoids text growth, restores fallback, stops queries; preview/shutdown and own focus unchanged; no foreign windows or hardware")
}
