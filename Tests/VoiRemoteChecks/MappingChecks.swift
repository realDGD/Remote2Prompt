import Foundation
import VoiRemoteCore

func mappingChecks() -> [(String, () throws -> Void)] {
    [
        ("schema 1 migrates without enabling device takeover", {
            let config = try AppConfiguration.decode(Data("{\"schemaVersion\":1,\"voiceTrigger\":\"rightControl\"}".utf8))
            try expect(config.schemaVersion == AppConfiguration.currentSchemaVersion && config.voiceTrigger == .rightControl, "Migration lost preferences")
            try expect(!config.mappingsEnabled, "Migration enabled mappings")
        }),
        ("arbitrary shortcut round trips", {
            var config = AppConfiguration()
            let shortcut = KeyboardShortcut(keyCode: 99, modifiers: [.control, .shift])
            config.setShortcut(shortcut, for: .tv, gesture: .longPress)
            let decoded = try AppConfiguration.decode(config.encoded())
            try expect(decoded.invocation(for: .tv, gesture: .longPress).shortcut == shortcut, "Shortcut lost")
        }),
        ("incomplete custom shortcuts are rejected", {
            var config = AppConfiguration()
            config.setAction(.customShortcut, for: .home, gesture: .click)
            do { _ = try AppConfiguration.decode(config.encoded()); throw CheckFailure(description: "Incomplete shortcut accepted") }
            catch ConfigurationError.invalidShortcut {}
            config.setShortcut(KeyboardShortcut(keyCode: 999), for: .home, gesture: .click)
            do { _ = try AppConfiguration.decode(config.encoded()); throw CheckFailure(description: "Invalid keycode accepted") }
            catch ConfigurationError.invalidShortcut {}
        }),
        ("Xiaomi synthetic reports decode voice and normal keys", {
            let report: [UInt8] = [0x3E, 0, 0x52, 0, 0, 0]
            try expect(XiaomiRemote.usages(reportID: 1, bytes: report) == [0x3E, 0x52], "Report decoded incorrectly")
            try expect(XiaomiRemote.usages(reportID: 1, bytes: [1] + report) == [0x3E, 0x52], "ID prefix not handled")
            try expect(XiaomiRemote.usages(reportID: 1, bytes: [0, 0, 0, 0, 0, 0]) == [], "Release not decoded")
            try expect(XiaomiRemote.buttonUsages[0x3E] == nil, "Voice entered the ordinary gesture path")
        }),
        ("malformed and unrelated reports never become releases", {
            try expect(XiaomiRemote.usages(reportID: 1, bytes: [0x52]) == nil, "Truncated report accepted")
            try expect(XiaomiRemote.usages(reportID: 2, bytes: [0, 0, 0, 0, 0, 0]) == nil, "Other report ID accepted")
            try expect(XiaomiRemote.usages(reportID: 1, bytes: [9, 0x52, 0, 0, 0, 0, 0]) == nil, "Wrong prefix accepted")
        }),
        ("plain click is immediate and duplicate down is ignored", {
            var config = AppConfiguration(); config.setAction(.copy, for: .select, gesture: .click)
            var engine = ButtonGestures()
            try expect(engine.handle(owner: "a", button: .select, isDown: true, at: 0, configuration: config).map(\.action) == [.copy], "Click delayed")
            try expect(engine.handle(owner: "a", button: .select, isDown: true, at: 0.1, configuration: config).isEmpty, "Repeated hardware report triggered again")
            try expect(engine.advance(to: 10).isEmpty, "Copy repeated")
            try expect(engine.handle(owner: "a", button: .select, isDown: false, at: 11, configuration: config).isEmpty, "Release duplicated click")
        }),
        ("repeatable click repeats without a backlog", {
            var config = AppConfiguration(); config.setAction(.arrowUp, for: .up, gesture: .click)
            var engine = ButtonGestures()
            _ = engine.handle(owner: "a", button: .up, isDown: true, at: 0, configuration: config)
            try expect(engine.advance(to: 0.4).isEmpty, "Repeat too early")
            try expect(engine.advance(to: 0.46).count == 1, "Repeat missing")
            try expect(engine.advance(to: 100).count == 1, "Stalled timer replayed a backlog")
            _ = engine.handle(owner: "a", button: .up, isDown: false, at: 100.01, configuration: config)
            try expect(engine.advance(to: 101).isEmpty, "Repeat continued after release")
        }),
        ("double click suppresses both single clicks", {
            var config = AppConfiguration()
            config.setAction(.copy, for: .select, gesture: .click)
            config.setAction(.paste, for: .select, gesture: .doubleClick)
            var engine = ButtonGestures()
            try expect(engine.handle(owner: "a", button: .select, isDown: true, at: 0, configuration: config).isEmpty, "Single click fired early")
            _ = engine.handle(owner: "a", button: .select, isDown: false, at: 0.05, configuration: config)
            _ = engine.handle(owner: "a", button: .select, isDown: true, at: 0.15, configuration: config)
            try expect(engine.handle(owner: "a", button: .select, isDown: false, at: 0.2, configuration: config).map(\.action) == [.paste], "Double click missing")
            try expect(engine.advance(to: 1).isEmpty, "Double click left a pending single")
        }),
        ("single click waits only when double click is configured", {
            var config = AppConfiguration()
            config.setAction(.copy, for: .select, gesture: .click)
            config.setAction(.paste, for: .select, gesture: .doubleClick)
            var engine = ButtonGestures()
            _ = engine.handle(owner: "a", button: .select, isDown: true, at: 0, configuration: config)
            _ = engine.handle(owner: "a", button: .select, isDown: false, at: 0.05, configuration: config)
            try expect(engine.advance(to: 0.34).isEmpty, "Single click too early")
            try expect(engine.advance(to: 0.36).map(\.action) == [.copy], "Single click lost")
        }),
        ("long press fires once and suppresses click and repeat", {
            var config = AppConfiguration()
            config.setAction(.arrowUp, for: .up, gesture: .click)
            config.setAction(.paste, for: .up, gesture: .longPress)
            var engine = ButtonGestures()
            _ = engine.handle(owner: "a", button: .up, isDown: true, at: 0, configuration: config)
            try expect(engine.advance(to: 0.54).isEmpty, "Long press too early")
            try expect(engine.advance(to: 0.56).map(\.action) == [.paste], "Long press missing")
            try expect(engine.advance(to: 1).isEmpty, "Long press repeated")
            try expect(engine.handle(owner: "a", button: .up, isDown: false, at: 2, configuration: config).isEmpty, "Long press emitted a click")
        }),
        ("short hold with a long binding clicks on release", {
            var config = AppConfiguration()
            config.setAction(.copy, for: .home, gesture: .click)
            config.setAction(.paste, for: .home, gesture: .longPress)
            var engine = ButtonGestures()
            _ = engine.handle(owner: "a", button: .home, isDown: true, at: 0, configuration: config)
            try expect(engine.handle(owner: "a", button: .home, isDown: false, at: 0.1, configuration: config).map(\.action) == [.copy], "Short hold lost click")
        }),
        ("disconnect cancels pending actions for only its owner", {
            var config = AppConfiguration()
            config.setAction(.copy, for: .home, gesture: .click)
            config.setAction(.paste, for: .home, gesture: .doubleClick)
            var engine = ButtonGestures()
            for owner in ["a", "b"] {
                _ = engine.handle(owner: owner, button: .home, isDown: true, at: 0, configuration: config)
                _ = engine.handle(owner: owner, button: .home, isDown: false, at: 0.05, configuration: config)
            }
            engine.cancel(owner: "a")
            try expect(engine.advance(to: 1).map(\.action) == [.copy], "Owner cancellation affected another remote")
            engine.cancelAll()
            try expect(engine.advance(to: 2).isEmpty, "Cancelled timer fired")
        })
    ]
}
