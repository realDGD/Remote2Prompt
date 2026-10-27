import ApplicationServices
import IOKit.hid
import Foundation

struct PermissionSnapshot: Sendable {
    let listen: IOHIDAccessType
    let control: Bool
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
}
