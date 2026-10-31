import Foundation
import VoiRemoteCore

enum LegacySettingsMigration {
    static func migrate(to defaults: UserDefaults, legacy: [String: Any]?) {
        let marker = "identityMigration.finished.v1"
        guard !defaults.bool(forKey: marker) else { return }
        defer { defaults.set(true, forKey: marker) }
        guard defaults.object(forKey: "configuration.v1") == nil,
              defaults.object(forKey: "initialSetup.finished.v1") == nil else { return }
        // Preserve raw bytes, including unreadable configurations, for the normal store to handle.
        for key in ["configuration.v1", "initialSetup.finished.v1", "setup.pending.v1", "initialSetup.presented.v1"] {
            if let value = legacy?[key] { defaults.set(value, forKey: key) }
        }
    }
}
