import ApplicationServices
import IOKit.hid
import Foundation

struct PermissionSnapshot: Sendable {
    let listen: IOHIDAccessType
    let control: Bool
}

struct ListenRequestResult: Sendable {
    let before: IOHIDAccessType
    let hid: Bool
    let event: Bool
    let after: IOHIDAccessType
}

/// A slow TCC round trip must not block the main run loop or accumulate polling work.
@MainActor
final class PermissionProbe {
    private let queue = DispatchQueue(label: "dev.remote2prompt.permissions", qos: .userInitiated)
    private var querying = false

    func fetch(_ completion: @escaping @MainActor @Sendable (PermissionSnapshot) -> Void) {
        guard !querying else { return }
        querying = true
        queue.async { [weak self] in
            let snapshot = PermissionSnapshot(listen: IOHIDCheckAccess(kIOHIDRequestTypeListenEvent), control: AXIsProcessTrusted())
            Task { @MainActor in
                self?.querying = false
                completion(snapshot)
            }
        }
    }

    func requestListening(_ completion: @escaping @MainActor @Sendable (ListenRequestResult) -> Void) {
        queue.async {
            let before = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
            let hid = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            let event = hid || CGRequestListenEventAccess()
            let after = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
            let result = ListenRequestResult(before: before, hid: hid, event: event, after: after)
            Task { @MainActor in completion(result) }
        }
    }

    func requestControl(_ completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        queue.async {
            let granted = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
            Task { @MainActor in completion(granted) }
        }
    }
}
