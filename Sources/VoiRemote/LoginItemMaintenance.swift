import Foundation
import ServiceManagement

@MainActor
struct LoginItemService {
    var status: () -> SMAppService.Status
    var register: () throws -> Void
    var unregister: () throws -> Void

    static var live: Self {
        Self(status: { SMAppService.mainApp.status },
             register: { try SMAppService.mainApp.register() },
             unregister: { try SMAppService.mainApp.unregister() })
    }
}

/// Installation-only recovery; ordinary launches never register a login item implicitly.
@MainActor
enum LoginItemMaintenance {
    private static let pendingPreference = "loginItem.restoreAfterInstall.v1"

    static func isPending(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: pendingPreference)
    }

    static func cancelPending(in defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingPreference)
        defaults.synchronize()
    }

    static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: "enabled"
        case .requiresApproval: "requiresApproval"
        case .notRegistered: "notRegistered"
        case .notFound: "notFound"
        @unknown default: "unknown"
        }
    }

    static func prepareForRemoval(defaults: UserDefaults = .standard, service: LoginItemService = .live) throws {
        switch service.status() {
        case .enabled:
            // Commit intent before unregistering. A failed removal/install can retry safely.
            defaults.set(true, forKey: pendingPreference)
            guard defaults.synchronize() else { throw Failure.persistence }
            try service.unregister()
        case .requiresApproval:
            // Respect a user revocation in System Settings rather than enabling it on install.
            cancelPending(in: defaults)
            try service.unregister()
        case .notRegistered, .notFound:
            break // Keep an earlier interrupted installation's recovery request.
        @unknown default:
            throw Failure.unavailable
        }
    }

    static func restoreAfterInstall(defaults: UserDefaults = .standard, service: LoginItemService = .live) throws {
        guard isPending(in: defaults) else { return }
        switch service.status() {
        case .enabled, .requiresApproval:
            break // Already registered, or the user must approve: never override that choice.
        case .notRegistered, .notFound:
            try service.register()
        @unknown default:
            throw Failure.unavailable
        }
        guard [.enabled, .requiresApproval].contains(service.status()) else { throw Failure.unavailable }
        cancelPending(in: defaults)
    }

    enum Failure: LocalizedError {
        case persistence, unavailable
        var errorDescription: String? {
            switch self {
            case .persistence: "Could not save login-item recovery state; the login item was not removed."
            case .unavailable: "Could not confirm login-item recovery; retry from General settings."
            }
        }
    }
}
