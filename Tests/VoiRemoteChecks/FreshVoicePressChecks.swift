import VoiRemoteCore

func freshVoicePressChecks() -> [(String, () throws -> Void)] {
    [
        ("initial voice press is armed but wake requires a released report per owner", {
            var gate = FreshVoicePressGate()
            try expect(gate.accepts(owner: "first", isDown: true), "Initial press was blocked")
            gate.requireRelease()
            try expect(!gate.accepts(owner: "first", isDown: true), "Held voice across wake was armed")
            try expect(!gate.accepts(owner: "first", isDown: true), "Repeated held report was armed")
            try expect(gate.accepts(owner: "first", isDown: false), "Release was ignored")
            try expect(gate.accepts(owner: "first", isDown: true), "Fresh press was blocked")
            try expect(!gate.accepts(owner: "second", isDown: true), "Another owner borrowed arming")
        }),
        ("disconnect and another suspension invalidate prior voice arming", {
            var gate = FreshVoicePressGate(); gate.requireRelease()
            _ = gate.accepts(owner: "first", isDown: false)
            gate.remove(owner: "first")
            try expect(!gate.accepts(owner: "first", isDown: true), "Disconnect retained arming")
            _ = gate.accepts(owner: "first", isDown: false)
            gate.requireRelease()
            try expect(!gate.accepts(owner: "first", isDown: true), "Another sleep retained arming")
        })
    ]
}
