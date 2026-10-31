import Foundation
import VoiRemoteCore

func advancedGestureChecks() -> [(String, () throws -> Void)] {
    func fixture() -> AppConfiguration {
        var c = AppConfiguration(); c.setAction(.arrowUp, for: .up, gesture: .click)
        return c
    }
    return [
        ("gesture deadlines choose the earliest owner and disappear after cancellation", {
            var c = fixture(); var g = ButtonGestures()
            try expect(g.nextDeadline == nil, "Idle recognizer requested polling")
            _ = g.handle(owner: "a", button: .up, isDown: true, at: 0, configuration: c)
            c.gestureTiming.repeatDelayMilliseconds = 200
            _ = g.handle(owner: "b", button: .up, isDown: true, at: 0.1, configuration: c)
            try expect(abs((g.nextDeadline ?? 0) - 0.3) < 0.00001, "Earlier owner deadline lost")
            g.cancel(owner: "b")
            try expect(g.nextDeadline == 0.45, "Cancel lost another owner deadline")
            _ = g.advance(to: 0.451)
            try expect(abs((g.nextDeadline ?? 0) - 0.531) < 0.00001, "Repeat did not rearm one future deadline")
            g.cancelAll(); try expect(g.nextDeadline == nil, "Cancelled recognizer kept a wakeup")
        }),
        ("custom unmodified navigation repeats automatically but modified commands do not", {
            var c = AppConfiguration(); c.setShortcut(.init(keyCode: 123), for: .up, gesture: .click)
            var g = ButtonGestures()
            try expect(g.handle(owner: "a", button: .up, isDown: true, at: 0, configuration: c).count == 1 && g.advance(to: 0.46).count == 1, "Custom arrow did not repeat")
            c.setShortcut(.init(keyCode: 36, modifiers: .command), for: .up, gesture: .click); g.cancelAll()
            _ = g.handle(owner: "a", button: .up, isDown: true, at: 1, configuration: c)
            try expect(g.advance(to: 10).isEmpty, "Submit command repeated automatically")
        }),
        ("configured timings and repeat disable are applied", {
            var c = fixture(); c.gestureTiming.repeatDelayMilliseconds = 200; c.gestureTiming.repeatIntervalMilliseconds = 50
            var g = ButtonGestures(); _ = g.handle(owner: "a", button: .up, isDown: true, at: 0, configuration: c)
            try expect(g.advance(to: 0.19).isEmpty && g.advance(to: 0.201).count == 1 && g.advance(to: 0.252).count == 1, "Configured repeat timing ignored")
            var b = ButtonBehavior(); b.clickRepeat = .disabled; c.setBehavior(b, for: .up); g.cancelAll()
            _ = g.handle(owner: "a", button: .up, isDown: true, at: 1, configuration: c)
            try expect(g.advance(to: 10).isEmpty, "Explicit repeat disable ignored")
        }),
        ("long repeat never leaks single actions before or after recognition", {
            var c = fixture(); c.setAction(.paste, for: .up, gesture: .longPress)
            var b = ButtonBehavior(); b.clickRepeat = .enabled; b.longPressRepeats = true; c.setBehavior(b, for: .up)
            var g = ButtonGestures(); _ = g.handle(owner: "a", button: .up, isDown: true, at: 0, configuration: c)
            try expect(g.advance(to: 0.46).isEmpty, "Single repeat escaped before long recognition")
            try expect(g.advance(to: 0.551).map(\.action) == [.paste] && g.advance(to: 0.632).map(\.action) == [.paste], "Long action did not repeat")
            try expect(g.advance(to: 100).count == 1, "Long repeat replayed a backlog")
            try expect(g.handle(owner: "a", button: .up, isDown: false, at: 100.01, configuration: c).isEmpty && g.advance(to: 101).isEmpty, "Release duplicated or continued the long action")
        }),
        ("opt-in second hold repeats double and never changes into long", {
            var c = fixture(); c.setAction(.copy, for: .up, gesture: .doubleClick); c.setAction(.paste, for: .up, gesture: .longPress)
            var b = ButtonBehavior(); b.doubleClickHoldRepeats = true; c.setBehavior(b, for: .up)
            var g = ButtonGestures()
            _ = g.handle(owner: "a", button: .up, isDown: true, at: 0, configuration: c)
            _ = g.handle(owner: "a", button: .up, isDown: false, at: 0.05, configuration: c)
            try expect(g.handle(owner: "a", button: .up, isDown: true, at: 0.15, configuration: c).map(\.action) == [.copy], "Second down did not commit double")
            try expect(g.advance(to: 0.59).isEmpty && g.advance(to: 0.601).map(\.action) == [.copy] && g.advance(to: 0.72).map(\.action) == [.copy], "Held double switched to long or ignored its delay")
            try expect(g.handle(owner: "a", button: .up, isDown: false, at: 0.73, configuration: c).isEmpty, "Release duplicated double")
        }),
        ("legacy second hold still becomes long and normal double remains release based", {
            var c = fixture(); c.setAction(.copy, for: .up, gesture: .doubleClick); c.setAction(.paste, for: .up, gesture: .longPress)
            var g = ButtonGestures()
            for (time, down) in [(0.0,true),(0.05,false),(0.15,true)] { _ = g.handle(owner: "a", button: .up, isDown: down, at: time, configuration: c) }
            try expect(g.advance(to: 0.701).map(\.action) == [.paste], "Legacy second hold changed")
            _ = g.handle(owner: "a", button: .up, isDown: false, at: 0.71, configuration: c)
            for (time, down) in [(1.0,true),(1.05,false),(1.15,true)] { try expect(g.handle(owner: "a", button: .up, isDown: down, at: time, configuration: c).isEmpty, "Legacy double fired before release") }
            try expect(g.handle(owner: "a", button: .up, isDown: false, at: 1.2, configuration: c).map(\.action) == [.copy], "Legacy double missing")
        }),
        ("first hold with double only can explicitly resolve to repeating single", {
            var c = fixture(); c.setAction(.copy, for: .up, gesture: .doubleClick)
            var b = ButtonBehavior(); b.clickRepeat = .enabled; c.setBehavior(b, for: .up)
            var g = ButtonGestures(); _ = g.handle(owner: "a", button: .up, isDown: true, at: 0, configuration: c)
            try expect(g.advance(to: 0.44).isEmpty && g.advance(to: 0.451).map(\.action) == [.arrowUp], "First hold did not disambiguate to single")
            try expect(g.handle(owner: "a", button: .up, isDown: false, at: 0.46, configuration: c).isEmpty && g.advance(to: 1).isEmpty, "First hold left a pending click")
        }),
        ("gesture snapshots options and cancellation clears repeating owners separately", {
            var c = fixture(); var g = ButtonGestures()
            for owner in ["a", "b"] { _ = g.handle(owner: owner, button: .up, isDown: true, at: 0, configuration: c) }
            c.gestureTiming.repeatDelayMilliseconds = 1000
            g.cancel(owner: "a")
            try expect(g.advance(to: 0.451).count == 1, "Owner cancellation or timing snapshot changed")
            g.cancelAll(); try expect(g.advance(to: 10).isEmpty, "Cancelled repeat revived")
            try expect(g.handle(owner: "a", button: .up, isDown: true, at: .nan, configuration: c).isEmpty && g.advance(to: .infinity).isEmpty, "Invalid clock accepted")
        }),
        ("custom double and long thresholds use configured milliseconds", {
            var c = fixture(); c.setAction(.copy, for: .up, gesture: .doubleClick); c.setAction(.paste, for: .up, gesture: .longPress)
            c.gestureTiming.doubleClickMilliseconds = 500; c.gestureTiming.longPressMilliseconds = 800
            var g = ButtonGestures()
            _ = g.handle(owner: "a", button: .up, isDown: true, at: 0, configuration: c)
            _ = g.handle(owner: "a", button: .up, isDown: false, at: 0.05, configuration: c)
            try expect(g.advance(to: 0.4).isEmpty && g.advance(to: 0.551).map(\.action) == [.arrowUp], "Double timeout ignored configuration")
            _ = g.handle(owner: "a", button: .up, isDown: true, at: 1, configuration: c)
            try expect(g.advance(to: 1.6).isEmpty && g.advance(to: 1.801).map(\.action) == [.paste], "Long threshold ignored configuration")
        })
    ]
}
