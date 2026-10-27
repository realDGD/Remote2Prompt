import Remote2PromptCore

func setupChecks() -> [(String, () throws -> Void)] {
    [
        ("setup requires two distinct paired ordinary keys", {
            var check = SetupInputCheck()
            check.beginButtons()
            check.receive(owner: "a", previous: [], current: [0x52])
            try expect(check.buttons.isEmpty, "A press alone completed a button")
            check.receive(owner: "a", previous: [0x52], current: [])
            check.receive(owner: "a", previous: [], current: [0x52])
            check.receive(owner: "a", previous: [0x52], current: [])
            try expect(!check.buttonsComplete, "The same button counted twice")
            check.receive(owner: "a", previous: [], current: [0x51])
            check.receive(owner: "a", previous: [0x51], current: [])
            try expect(check.buttonsComplete && !check.complete, "Ordinary keys claimed voice success")
        }),
        ("setup ignores old releases voice and other remotes", {
            var check = SetupInputCheck()
            check.beginButtons()
            check.receive(owner: "b", previous: [], current: [XiaomiRemote.voiceUsage])
            check.receive(owner: "a", previous: [0x52], current: [])
            try expect(check.buttons.isEmpty, "Old release or voice counted as a normal key")
            check.receive(owner: "a", previous: [], current: [0x52])
            check.receive(owner: "b", previous: [0x52], current: [])
            try expect(check.buttons.isEmpty, "Other remote released the selected remote's key")
            check.receive(owner: "a", previous: [0x52], current: [])
            check.receive(owner: "b", previous: [], current: [0x51])
            check.receive(owner: "b", previous: [0x51], current: [])
            try expect(check.buttons == [.up], "Other source contaminated this attempt")
        }),
        ("setup voice must begin and end within its own stage", {
            var check = SetupInputCheck()
            check.beginVoice()
            try expect(check.stage == .idle, "Voice stage skipped ordinary buttons")
            check.beginButtons()
            for usage: UInt16 in [0x52, 0x51] {
                check.receive(owner: "a", previous: [], current: [usage])
                check.receive(owner: "a", previous: [usage], current: [])
            }
            check.beginVoice()
            check.receive(owner: "a", previous: [XiaomiRemote.voiceUsage], current: [])
            try expect(!check.complete, "An old voice release completed setup")
            check.receive(owner: "b", previous: [], current: [XiaomiRemote.voiceUsage])
            check.receive(owner: "b", previous: [XiaomiRemote.voiceUsage], current: [])
            try expect(!check.voicePressed, "Other remote passed the voice check")
            check.receive(owner: "a", previous: [], current: [XiaomiRemote.voiceUsage])
            check.receive(owner: "a", previous: [XiaomiRemote.voiceUsage], current: [XiaomiRemote.voiceUsage])
            try expect(check.voicePressed && !check.complete, "Duplicate report acted as release")
            check.receive(owner: "a", previous: [XiaomiRemote.voiceUsage], current: [])
            try expect(check.complete, "Paired voice was not detected")
            check.disconnected(owner: "b")
            try expect(check.complete, "Unrelated disconnect invalidated the check")
            check.disconnected(owner: "a")
            try expect(check == SetupInputCheck(), "Disconnected device retained stale success")
        }),
        ("rerunning setup clears all earlier input evidence", {
            var check = SetupInputCheck()
            check.beginButtons()
            check.receive(owner: "a", previous: [], current: [0x52])
            check.beginButtons()
            check.receive(owner: "a", previous: [0x52], current: [])
            try expect(check.buttons.isEmpty && !check.voicePressed, "A prior attempt survived a restart")
        }),
        ("basic navigation fill preserves custom clicks and other gestures", {
            var config = AppConfiguration()
            let shortcut = KeyboardShortcut(keyCode: 40, modifiers: [.control, .option])
            config.setShortcut(shortcut, for: .up, gesture: .click)
            config.setAction(.copy, for: .down, gesture: .doubleClick)
            config.fillBasicNavigationBindings()
            let once = config
            config.fillBasicNavigationBindings()
            try expect(config == once, "Rerunning defaults changed settings")
            try expect(config.invocation(for: .up, gesture: .click).shortcut == shortcut, "Custom click was overwritten")
            try expect(config.action(for: .down, gesture: .doubleClick) == .copy, "Double click was overwritten")
            try expect(config.action(for: .down, gesture: .click) == .arrowDown && !config.mappingsEnabled, "Fill enabled takeover or missed empty click")
        })
    ]
}
