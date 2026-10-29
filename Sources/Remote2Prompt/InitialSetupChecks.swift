import Foundation
import Remote2PromptCore

private enum InitialSetupCheckFailure: Error { case failed(String) }

/// Runs against the actual store in a disposable defaults domain, never production settings.
@MainActor
func checkInitialSetupLifecycle() throws {
    let domain = "dev.remote2prompt.self-check." + UUID().uuidString
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
    first.isSetupPresented = false // Skip setup without saving draft configuration.
    first.presentInitialSetupIfNeeded()
    try require(!first.isSetupPresented && defaults.object(forKey: key) == nil,
                "Skip changed configuration or presented setup again")
    let restarted = ConfigurationStore(defaults: defaults)
    restarted.presentInitialSetupIfNeeded()
    try require(!restarted.isSetupPresented, "Presentation marker did not survive store recreation")
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

    defaults.removePersistentDomain(forName: domain)
    let broken = Data("unreadable configuration".utf8)
    defaults.set(broken, forKey: key)
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
