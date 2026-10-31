import Foundation
import VoiRemoteCore

private enum InitialSetupCheckFailure: Error { case failed(String) }

/// Runs against the actual store in a disposable defaults domain, never production settings.
@MainActor
func checkInitialSetupLifecycle() throws {
    let domain = "dev.voiremote.self-check." + UUID().uuidString
    guard let defaults = UserDefaults(suiteName: domain) else {
        throw InitialSetupCheckFailure.failed("Could not create isolated defaults")
    }
    defer { defaults.removePersistentDomain(forName: domain) }
    func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw InitialSetupCheckFailure.failed(message) }
    }
    let key = "configuration.v1"
    let first = ConfigurationStore(defaults: defaults)
    first.presentInitialSetupIfNeeded()
    try require(first.isSetupPresented, "Fresh install did not present setup")
    let interrupted = ConfigurationStore(defaults: defaults)
    interrupted.presentInitialSetupIfNeeded()
    try require(interrupted.isSetupPresented && defaults.object(forKey: key) == nil,
                "Process restart lost the unfinished wizard")
    interrupted.finishSetupPresentation() // Explicit skip without saving draft configuration.
    interrupted.presentInitialSetupIfNeeded()
    try require(!interrupted.isSetupPresented && defaults.object(forKey: key) == nil,
                "Skip changed configuration or presented setup again")
    let restarted = ConfigurationStore(defaults: defaults)
    restarted.presentInitialSetupIfNeeded()
    try require(!restarted.isSetupPresented, "Explicit skip did not survive store recreation")
    restarted.isSetupPresented = true
    try require(restarted.isSetupPresented, "Manual setup was blocked after skipping")

    defaults.removePersistentDomain(forName: domain)
    var existing = AppConfiguration()
    existing.setAction(.copy, for: .select, gesture: .doubleClick)
    let bytes = try existing.encoded()
    defaults.set(bytes, forKey: key)
    let upgraded = ConfigurationStore(defaults: defaults)
    upgraded.presentInitialSetupIfNeeded()
    try require(!upgraded.isSetupPresented && upgraded.configuration == existing && defaults.data(forKey: key) == bytes,
                "Upgrade presented setup or changed existing configuration")
    upgraded.isSetupPresented = true
    let manualRestart = ConfigurationStore(defaults: defaults)
    manualRestart.presentInitialSetupIfNeeded()
    try require(manualRestart.isSetupPresented && manualRestart.configuration == existing,
                "Manual wizard could not resume with existing settings")
    manualRestart.finishSetupPresentation()
    let finished = ConfigurationStore(defaults: defaults)
    finished.presentInitialSetupIfNeeded()
    try require(!finished.isSetupPresented, "Finished manual wizard repeated after restart")

    defaults.removePersistentDomain(forName: domain)
    defaults.set(true, forKey: "initialSetup.presented.v1") // 0.2.9 never recorded completion.
    let legacy = ConfigurationStore(defaults: defaults)
    legacy.presentInitialSetupIfNeeded()
    try require(legacy.isSetupPresented, "Legacy presentation marker hid an interrupted first run")

    defaults.removePersistentDomain(forName: domain)
    let broken = Data("unreadable configuration".utf8)
    defaults.set(broken, forKey: key)
    defaults.set(true, forKey: "setup.pending.v1")
    let unreadable = ConfigurationStore(defaults: defaults)
    unreadable.presentInitialSetupIfNeeded()
    try require(!unreadable.isSetupPresented && unreadable.persistenceError != nil && defaults.data(forKey: key) == broken,
                "Unreadable settings were overwritten or prompted setup")

    defaults.removePersistentDomain(forName: domain)
    let imported = ConfigurationStore(defaults: defaults)
    try imported.replace(with: existing)
    imported.presentInitialSetupIfNeeded()
    try require(!imported.isSetupPresented && imported.configuration == existing,
                "Explicit import before presentation was treated as a new install")
}

@MainActor
func checkDesktopSettings() throws {
    let domain = "dev.voiremote.migration-check." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    let raw = try AppConfiguration().encoded()
    LegacySettingsMigration.migrate(to: defaults, legacy: ["configuration.v1": raw, "initialSetup.finished.v1": true])
    guard defaults.data(forKey: "configuration.v1") == raw, defaults.bool(forKey: "initialSetup.finished.v1") else {
        throw InitialSetupCheckFailure.failed("Legacy settings were not preserved")
    }
    defaults.set(Data([1, 2]), forKey: "configuration.v1")
    LegacySettingsMigration.migrate(to: defaults, legacy: ["configuration.v1": raw])
    guard defaults.data(forKey: "configuration.v1") == Data([1, 2]) else {
        throw InitialSetupCheckFailure.failed("Migration overwrote current settings")
    }
    defaults.removePersistentDomain(forName: domain)
    LegacySettingsMigration.migrate(to: defaults, legacy: ["configuration.v1": Data([0xff])])
    guard ConfigurationStore(defaults: defaults).persistenceError != nil else {
        throw InitialSetupCheckFailure.failed("Migration hid unreadable legacy settings")
    }
    let exported = try ConfigurationTransfer.export(AppConfiguration())
    var document = try JSONSerialization.jsonObject(with: exported) as! [String: Any]
    document["format"] = LegacyIdentity.configurationFormat
    _ = try ConfigurationTransfer.load(JSONSerialization.data(withJSONObject: document))
}
