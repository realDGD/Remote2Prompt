import Combine
import Foundation
import Remote2PromptCore

@MainActor
final class ConfigurationStore: ObservableObject {
    @Published private(set) var configuration = AppConfiguration()
    @Published private(set) var persistenceError: String?
    @Published var isSetupPresented = false
    private let defaults: UserDefaults
    private let key = "configuration.v1"

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
}
