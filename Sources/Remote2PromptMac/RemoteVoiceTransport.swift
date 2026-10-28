import Foundation
import Remote2PromptCore

/// Callbacks belong to the main actor. The runtime owns retry and session cancellation.
@MainActor public protocol RemoteVoiceTransport: AnyObject {
    var onReady: ((VoiceCapabilities) -> Void)? { get set }
    var onStarted: (() -> Void)? { get set }
    var onStopped: ((RemoteVoiceStopReason) -> Void)? { get set }
    var onAudio: ((Data) -> Void)? { get set }
    var onSync: ((Data) -> Void)? { get set }
    var onStatus: ((String) -> Void)? { get set }
    var onFailure: ((String) -> Void)? { get set }
    func start()
    func stop()
    @discardableResult func open() -> Bool
    @discardableResult func close() -> Bool
}
