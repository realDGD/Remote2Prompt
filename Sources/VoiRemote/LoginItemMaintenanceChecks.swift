import Foundation
import ServiceManagement

@MainActor
func checkLoginItemMaintenance() throws {
    enum CheckFailure: Error { case failed(String), simulated }
    func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
        if !value() { throw CheckFailure.failed(message) }
    }
    let domain = "dev.voiremote.login-check." + UUID().uuidString
    let defaults = UserDefaults(suiteName: domain)!
    defer { defaults.removePersistentDomain(forName: domain) }
    var state = SMAppService.Status.enabled
    var events: [String] = []
    var refuseRegistration = false
    var refuseRemoval = false
    let service = LoginItemService(status: { state }, register: {
        events.append("register")
        if refuseRegistration { throw CheckFailure.simulated }
        state = .enabled
    }, unregister: {
        if state == .enabled {
            try require(LoginItemMaintenance.isPending(in: defaults), "Removal preceded recovery persistence")
        }
        events.append("unregister")
        if refuseRemoval { throw CheckFailure.simulated }
        state = .notRegistered
    })

    try LoginItemMaintenance.prepareForRemoval(defaults: defaults, service: service)
    try require(state == .notRegistered, "Removal did not unregister")
    try LoginItemMaintenance.restoreAfterInstall(defaults: defaults, service: service)
    try require(state == .enabled && events == ["unregister", "register"] && !LoginItemMaintenance.isPending(in: defaults),
                "Enabled login item did not survive installation")

    events.removeAll(); state = .notFound
    try LoginItemMaintenance.prepareForRemoval(defaults: defaults, service: service)
    try LoginItemMaintenance.restoreAfterInstall(defaults: defaults, service: service)
    try require(events.isEmpty, "Fresh or disabled installation enabled a login item")

    state = .enabled
    try LoginItemMaintenance.prepareForRemoval(defaults: defaults, service: service)
    refuseRegistration = true
    do {
        try LoginItemMaintenance.restoreAfterInstall(defaults: defaults, service: service)
        throw CheckFailure.failed("Registration failure was hidden")
    } catch CheckFailure.simulated {}
    try require(LoginItemMaintenance.isPending(in: defaults), "Failure discarded recovery intent")
    try LoginItemMaintenance.prepareForRemoval(defaults: defaults, service: service)
    try require(LoginItemMaintenance.isPending(in: defaults), "Repeated cleanup lost an interrupted recovery")
    refuseRegistration = false
    try LoginItemMaintenance.restoreAfterInstall(defaults: defaults, service: service)
    try require(state == .enabled, "Retry did not recover")

    refuseRemoval = true
    do {
        try LoginItemMaintenance.prepareForRemoval(defaults: defaults, service: service)
        throw CheckFailure.failed("Removal failure was hidden")
    } catch CheckFailure.simulated {}
    let prior = events.count
    try LoginItemMaintenance.restoreAfterInstall(defaults: defaults, service: service)
    try require(events.count == prior && !LoginItemMaintenance.isPending(in: defaults), "Already enabled recovery registered twice")
    refuseRemoval = false

    try LoginItemMaintenance.prepareForRemoval(defaults: defaults, service: service)
    state = .requiresApproval
    let count = events.count
    try LoginItemMaintenance.restoreAfterInstall(defaults: defaults, service: service)
    try require(state == .requiresApproval && events.count == count, "Recovery overrode system disapproval")
    try LoginItemMaintenance.prepareForRemoval(defaults: defaults, service: service)
    try require(!LoginItemMaintenance.isPending(in: defaults), "Disallowed service was queued for re-enabling")

    state = .enabled
    try LoginItemMaintenance.prepareForRemoval(defaults: defaults, service: service)
    LoginItemMaintenance.cancelPending(in: defaults) // Explicit user disable or zap.
    let before = events.count
    try LoginItemMaintenance.restoreAfterInstall(defaults: defaults, service: service)
    try require(events.count == before && state == .notRegistered, "Explicit disable was undone by installation")
}
