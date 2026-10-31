import Foundation
import VoiRemoteCore

func gestureOptionChecks() -> [(String, () throws -> Void)] {
    [
        ("old gesture configuration keeps timings and secondary-repeat opt-outs", {
            for version in 1...4 {
                let c = try AppConfiguration.decode(Data("{\"schemaVersion\":\(version),\"voiceEnabled\":false}".utf8))
                try expect(c.gestureTiming == GestureTiming() && c.buttonBehaviors.isEmpty && !c.voiceEnabled, "Migration changed behavior")
            }
        }),
        ("gesture preferences roundtrip and portable import keeps capabilities off", {
            var c = AppConfiguration(); c.gestureTiming.doubleClickMilliseconds = 420; c.gestureTiming.repeatIntervalMilliseconds = 50
            var b = ButtonBehavior(); b.clickRepeat = .disabled; b.longPressRepeats = true; b.doubleClickHoldRepeats = true
            c.setBehavior(b, for: .select); c.mappingsEnabled = true
            try expect(try AppConfiguration.decode(c.encoded()) == c, "Gesture options did not roundtrip")
            let imported = try ConfigurationTransfer.load(ConfigurationTransfer.export(c))
            try expect(imported.gestureTiming == c.gestureTiming && imported.behavior(for: .select) == b && !imported.mappingsEnabled, "Transfer lost preferences or enabled mapping")
            c.setBehavior(ButtonBehavior(), for: .select)
            try expect(c.buttonBehaviors.isEmpty, "Reset retained a redundant override")
        }),
        ("invalid timing and duplicate behavior overrides are rejected", {
            for value in [-1, 0, 29, 1001] {
                var c = AppConfiguration(); c.gestureTiming.repeatIntervalMilliseconds = value
                do { _ = try AppConfiguration.decode(c.encoded()); throw CheckFailure(description: "Invalid timing accepted") }
                catch ConfigurationError.invalidGestureSettings {}
            }
            var c = AppConfiguration(); c.buttonBehaviors = [.init(button: .up, behavior: .init()), .init(button: .up, behavior: .init())]
            do { _ = try AppConfiguration.decode(c.encoded()); throw CheckFailure(description: "Duplicate override accepted") }
            catch ConfigurationError.invalidGestureSettings {}
        }),
        ("partial timing fields inherit defaults and unknown repeat values fail", {
            let c = try AppConfiguration.decode(Data("{\"schemaVersion\":5,\"gestureTiming\":{\"doubleClickMilliseconds\":400}}".utf8))
            try expect(c.gestureTiming.doubleClickMilliseconds == 400 && c.gestureTiming.longPressMilliseconds == 550, "Partial fields lost defaults")
            do {
                _ = try AppConfiguration.decode(Data("{\"schemaVersion\":5,\"buttonBehaviors\":[{\"button\":\"up\",\"behavior\":{\"clickRepeat\":\"future\"}}]}".utf8))
                throw CheckFailure(description: "Unknown policy silently accepted")
            } catch is DecodingError {}
        })
    ]
}
