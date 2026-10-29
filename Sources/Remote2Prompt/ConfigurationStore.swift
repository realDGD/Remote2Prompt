import Combine
import Foundation
import Remote2PromptCore

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published private(set) var configuration = AppConfiguration()
    @Published private(set) var persistenceError: String?
    @Published var isSetupPresented = false {
        didSet {
            if isSetupPresented { defaults.set(true, forKey: pendingSetupKey) }
        }
    }
    private let defaults: UserDefaults
    private let key = "configuration.v1"
    private let initialSetupFinishedKey = "initialSetup.finished.v1"
    private let pendingSetupKey = "setup.pending.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: key) else { return }
        do {
            configuration = try AppConfiguration.decode(data)
        } catch {
            // Leave stored bytes intact; do not replace an unreadable or newer configuration.
            persistenceError = "设置无法读取，原始数据已保留。本次打开仅供查看：\(error.localizedDescription)"
        }
    }

    /// A process exit must not count as a completed or explicitly skipped wizard.
    func presentInitialSetupIfNeeded() {
        guard persistenceError == nil, !isSetupPresented else { return }
        let fresh = defaults.object(forKey: key) == nil && !defaults.bool(forKey: initialSetupFinishedKey)
        guard fresh || defaults.bool(forKey: pendingSetupKey) else { return }
        isSetupPresented = true
    }

    func finishSetupPresentation() {
        defaults.set(true, forKey: initialSetupFinishedKey)
        defaults.removeObject(forKey: pendingSetupKey)
        defaults.removeObject(forKey: "initialSetup.presented.v1")
        isSetupPresented = false
    }

    func update(_ change: (inout AppConfiguration) -> Void) {
        guard persistenceError == nil else { return }
        var next = configuration
        change(&next)
        do {
            let data = try next.encoded()
            defaults.set(data, forKey: key)
            configuration = next
        } catch {
            persistenceError = "设置无法保存：\(error.localizedDescription)"
        }
    }

    /// Explicit import is allowed to replace unreadable bytes only after the user's confirmation.
    func replace(with value: AppConfiguration) throws {
        let next = try AppConfiguration.decode(value.encoded())
        defaults.set(try next.encoded(), forKey: key)
        persistenceError = nil
        configuration = next
    }
}
