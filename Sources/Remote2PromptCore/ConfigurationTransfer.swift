import Foundation

/// Portable, bounded settings files; no local device identity or active capability is imported.
public enum ConfigurationTransfer {
    public static let maximumBytes = 262_144
    private struct Document: Codable {
        let format: String
        let version: Int
        let configuration: AppConfiguration
    }

    public static func export(_ configuration: AppConfiguration) throws -> Data {
        var portable = try AppConfiguration.decode(configuration.encoded())
        portable.selectedVirtualInputUID = nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Document(format: "Remote2Prompt.configuration", version: 1, configuration: portable))
        guard data.count <= maximumBytes else { throw TransferError.tooLarge }
        return data
    }

    public static func load(_ data: Data) throws -> AppConfiguration {
        guard data.count <= maximumBytes else { throw TransferError.tooLarge }
        let document = try JSONDecoder().decode(Document.self, from: data)
        guard document.format == "Remote2Prompt.configuration", document.version == 1 else { throw TransferError.unsupportedFormat }
        var configuration = try AppConfiguration.decode(document.configuration.encoded())
        configuration.selectedVirtualInputUID = nil
        configuration.mappingsEnabled = false
        configuration.voiceEnabled = false
        configuration.remoteAudioEnabled = false
        configuration.preferVirtualInput = false
        return configuration
    }

    public enum TransferError: Error, LocalizedError {
        case tooLarge, unsupportedFormat
        public var errorDescription: String? {
            switch self {
            case .tooLarge: "配置文件超过 256 KB 限制。"
            case .unsupportedFormat: "不是支持的 Remote2Prompt 配置文件，或来自较新的格式版本。"
            }
        }
    }
}
