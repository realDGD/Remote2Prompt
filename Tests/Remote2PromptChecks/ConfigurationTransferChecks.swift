import Foundation
import Remote2PromptCore

func configurationTransferChecks() -> [(String, () throws -> Void)] {
    func altered(_ transform: (inout [String: Any]) -> Void) throws -> Data {
        var object = try JSONSerialization.jsonObject(with: ConfigurationTransfer.export(AppConfiguration())) as! [String: Any]
        transform(&object)
        return try JSONSerialization.data(withJSONObject: object)
    }
    func rejects(_ data: Data) throws {
        do { _ = try ConfigurationTransfer.load(data); throw CheckFailure(description: "Invalid transfer accepted") }
        catch is CheckFailure { throw CheckFailure(description: "Invalid transfer accepted") }
        catch { }
    }
    return [
        ("portable config retains gestures and side-specific trigger with capabilities off", {
            var original = AppConfiguration()
            original.voiceTrigger = .rightOption
            original.mappingsEnabled = true; original.voiceEnabled = true
            original.remoteAudioEnabled = true; original.preferVirtualInput = true
            original.selectedVirtualInputUID = "private-device-marker"
            original.setShortcut(KeyboardShortcut(keyCode: 40, modifiers: [.command, .shift]), for: .home, gesture: .doubleClick)
            let data = try ConfigurationTransfer.export(original)
            try expect(!String(decoding: data, as: UTF8.self).contains("private-device-marker"), "Export contains a local device identity")
            let loaded = try ConfigurationTransfer.load(data)
            try expect(loaded.bindings == original.bindings && loaded.voiceTrigger == .rightOption, "Portable choices changed")
            try expect(!loaded.mappingsEnabled && !loaded.voiceEnabled && !loaded.remoteAudioEnabled && !loaded.preferVirtualInput && loaded.selectedVirtualInputUID == nil, "Import enabled hardware or retained a UID")
        }),
        ("config transfer validates format and future schema", {
            try rejects(altered { $0["format"] = "another-app" })
            try rejects(altered { $0["version"] = 2 })
            try rejects(altered { var c = $0["configuration"] as! [String: Any]; c["schemaVersion"] = 999; $0["configuration"] = c })
            try rejects(Data("{}".utf8))
        }),
        ("config transfer rejects duplicate mappings and malformed shortcuts", {
            let binding: [String: Any] = ["button": "up", "gesture": "click", "action": "copy"]
            try rejects(altered { var c = $0["configuration"] as! [String: Any]; c["bindings"] = [binding, binding]; $0["configuration"] = c })
            try rejects(altered { var c = $0["configuration"] as! [String: Any]; c["bindings"] = [["button": "up", "gesture": "click", "action": "customShortcut"]]; $0["configuration"] = c })
        }),
        ("config transfer is bounded before parsing and strips incoming device selection", {
            try rejects(Data(repeating: 32, count: ConfigurationTransfer.maximumBytes + 1))
            let loaded = try ConfigurationTransfer.load(altered {
                var c = $0["configuration"] as! [String: Any]
                c["selectedVirtualInputUID"] = "untrusted-device"; c["mappingsEnabled"] = true
                $0["configuration"] = c
            })
            try expect(loaded.selectedVirtualInputUID == nil && !loaded.mappingsEnabled, "Incoming identity or activation accepted")
        })
    ]
}
