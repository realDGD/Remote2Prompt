import Foundation
import Remote2PromptCore

func voiceReminderPlacementChecks() -> [(String, () throws -> Void)] {
    let size = CGSize(width: 264, height: 74)
    let primary = ReminderScreen(frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                                 visibleFrame: CGRect(x: 0, y: 24, width: 1440, height: 850))
    return [
        ("capsule placement stays stable when a text bubble grows upward", {
            let small = CGRect(x: 400, y: 500, width: 200, height: 130)
            let large = CGRect(x: 325, y: 450, width: 350, height: 180)
            let a = VoiceReminderPlacement.following(topLeftWindow: small, primaryMaxY: 900, screens: [primary], size: size)
            let b = VoiceReminderPlacement.following(topLeftWindow: large, primaryMaxY: 900, screens: [primary], size: size)
            try expect(a == CGPoint(x: 368, y: 188) && a == b, "Bubble growth changed the stable lower anchor")
        }),
        ("capsule placement follows left and upper screens independently of cursor position", {
            let left = ReminderScreen(frame: CGRect(x: -1200, y: -500, width: 1200, height: 800),
                                      visibleFrame: CGRect(x: -1200, y: -480, width: 1200, height: 760))
            let above = ReminderScreen(frame: CGRect(x: 0, y: 900, width: 1440, height: 800),
                                       visibleFrame: CGRect(x: 0, y: 900, width: 1440, height: 780))
            let l = VoiceReminderPlacement.following(topLeftWindow: CGRect(x: -1000, y: 1100, width: 350, height: 130), primaryMaxY: 900, screens: [primary, left], size: size)
            let u = VoiceReminderPlacement.following(topLeftWindow: CGRect(x: 400, y: -600, width: 350, height: 130), primaryMaxY: 900, screens: [primary, above], size: size)
            try expect(l == CGPoint(x: -957, y: -412), "Negative-origin screen conversion failed")
            try expect(u == CGPoint(x: 443, y: 1288), "Upper screen conversion failed")
        }),
        ("capsule at an edge places the reminder beside it without covering text", {
            let point = VoiceReminderPlacement.following(topLeftWindow: CGRect(x: 400, y: 760, width: 350, height: 130), primaryMaxY: 900, screens: [primary], size: size)
            try expect(point == CGPoint(x: 758, y: 36), "No room below should select a side")
            let anchor = CGRect(x: 400, y: 10, width: 350, height: 130)
            try expect(point.map { !CGRect(origin: $0, size: size).intersects(anchor) } == true, "Reminder covers text/capsule")
        }),
        ("invalid offscreen or impossible geometry requests fixed fallback", {
            let bad = CGRect(x: CGFloat.nan, y: 0, width: 300, height: 130)
            let offscreen = CGRect(x: 5000, y: 5000, width: 300, height: 130)
            let tiny = ReminderScreen(frame: CGRect(x: 0, y: 0, width: 200, height: 100), visibleFrame: CGRect(x: 0, y: 0, width: 200, height: 100))
            try expect(VoiceReminderPlacement.following(topLeftWindow: bad, primaryMaxY: 900, screens: [primary], size: size) == nil, "Invalid numbers accepted")
            try expect(VoiceReminderPlacement.following(topLeftWindow: offscreen, primaryMaxY: 900, screens: [primary], size: size) == nil, "Offscreen target guessed")
            try expect(VoiceReminderPlacement.following(topLeftWindow: CGRect(x: 0, y: 0, width: 200, height: 130), primaryMaxY: 100, screens: [tiny], size: size) == nil, "Panel escaped a tiny screen")
        })
    ]
}
