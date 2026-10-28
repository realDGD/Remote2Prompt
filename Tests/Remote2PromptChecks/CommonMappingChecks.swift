import Remote2PromptCore

func commonMappingChecks() -> [(String, () throws -> Void)] {
    [
        ("common preset matches all requested shortcut codes and modifiers", {
            var config = AppConfiguration(); config.fillBasicNavigationBindings()
            let expected: [(RemoteButton, ButtonGesture, UInt16, ShortcutModifiers)] = [
                (.power,.click,53,[]),(.power,.longPress,53,[]),
                (.up,.click,126,[]),(.up,.longPress,126,[.command,.function]),
                (.left,.click,123,[]),(.left,.longPress,123,[.command,.function]),
                (.right,.click,124,[]),(.right,.longPress,124,[.command,.function]),
                (.down,.click,125,[]),(.down,.longPress,125,[.command,.function]),
                (.select,.click,36,[]),(.select,.doubleClick,36,.command),(.select,.longPress,36,.shift),
                (.back,.click,51,[]),(.home,.click,6,.command),(.home,.longPress,6,[.command,.shift]),
                (.menu,.click,43,[]),(.volumeUp,.click,24,.shift),(.volumeDown,.click,27,[]),(.tv,.click,47,[])
            ]
            try expect(config.bindings.count == 20, "Preset must contain every listed binding")
            for (button, gesture, key, modifiers) in expected {
                try expect(config.invocation(for: button, gesture: gesture).resolvedShortcut == KeyboardShortcut(keyCode: key, modifiers: modifiers), "Unexpected preset for \(button).\(gesture)")
            }
            try expect(config.bindings.filter { $0.gesture == .click }.count == 12 && config.bindings.filter { $0.gesture == .doubleClick }.count == 1 && config.bindings.filter { $0.gesture == .longPress }.count == 7, "Gesture totals changed")
            try expect(!config.mappingsEnabled && !config.voiceEnabled && !config.preferVirtualInput, "Preset enabled a capability")
        }),
        ("preset fill preserves overrides in every gesture and round trips", {
            var config = AppConfiguration()
            for gesture in ButtonGesture.allCases { config.setAction(.copy, for: .select, gesture: gesture) }
            config.fillBasicNavigationBindings(); let first = config; config.fillBasicNavigationBindings()
            try expect(first == config, "Preset is not idempotent")
            for gesture in ButtonGesture.allCases { try expect(config.action(for: .select, gesture: gesture) == .copy, "Existing override lost") }
            try expect(try AppConfiguration.decode(config.encoded()) == config, "Preset does not round trip")
        }),
        ("preset select double and long gestures suppress its single action", {
            var config = AppConfiguration(); config.fillBasicNavigationBindings()
            var gestures = ButtonGestures()
            _ = gestures.handle(owner: "fixture", button: .select, isDown: true, at: 0, configuration: config)
            _ = gestures.handle(owner: "fixture", button: .select, isDown: false, at: 0.05, configuration: config)
            _ = gestures.handle(owner: "fixture", button: .select, isDown: true, at: 0.1, configuration: config)
            let double = gestures.handle(owner: "fixture", button: .select, isDown: false, at: 0.15, configuration: config)
            try expect(double.map(\.resolvedShortcut) == [KeyboardShortcut(keyCode: 36, modifiers: .command)] && gestures.advance(to: 1).isEmpty, "Double emitted another action")
            _ = gestures.handle(owner: "fixture", button: .select, isDown: true, at: 2, configuration: config)
            let long = gestures.advance(to: 2.6)
            try expect(long.map(\.resolvedShortcut) == [KeyboardShortcut(keyCode: 36, modifiers: .shift)], "Long action missing")
            try expect(gestures.handle(owner: "fixture", button: .select, isDown: false, at: 3, configuration: config).isEmpty, "Long emitted click")
        })
    ]
}
