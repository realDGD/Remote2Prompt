import Remote2PromptCore

func voiceLimitIndicatorChecks() -> [(String, () throws -> Void)] {
    [
        ("voice warning follows monotonic segment time and never invents a stop", {
            var indicator = VoiceLimitIndicator()
            indicator.begin(segment: 1, at: 100, hasRC003Limit: true)
            try expect(indicator.presentation(at: 149.99) == .hidden, "Warning appeared before 50 seconds")
            try expect(indicator.nextUpdate(at: 100) == 150, "Idle phase needs unnecessary polling")
            try expect(indicator.presentation(at: 150) == .countdown(seconds: 10, urgent: false), "50 second warning missing")
            try expect(indicator.presentation(at: 154.99) == .countdown(seconds: 6, urgent: false), "Warning rounded down too early")
            try expect(indicator.presentation(at: 155) == .countdown(seconds: 5, urgent: true), "Final five second state missing")
            try expect(indicator.presentation(at: 159.99) == .countdown(seconds: 1, urgent: true), "Last second missing")
            try expect(indicator.presentation(at: 160) == .approachingLimit && indicator.presentation(at: 170) == .approachingLimit, "A timer expiry invented device termination")
            try expect(indicator.nextUpdate(at: 151.2) == 152 && indicator.nextUpdate(at: 160) == nil, "Update deadlines drift or poll forever")
        }),
        ("only a confirmed device limit retains a three second end indication", {
            var indicator = VoiceLimitIndicator(); indicator.begin(segment: 1, at: 0, hasRC003Limit: true)
            indicator.end(segment: 1, reason: .deviceLimit, at: 60)
            try expect(indicator.presentation(at: 60) == .ended && indicator.presentation(at: 62.99) == .ended, "Confirmed limit was hidden too soon")
            try expect(indicator.presentation(at: 63) == .hidden && indicator.nextUpdate(at: 63) == nil, "End indication remained indefinitely")
            for reason in [VoiceLimitEndReason.released, .interrupted, .unknown] {
                var other = VoiceLimitIndicator(); other.begin(segment: 1, at: 0, hasRC003Limit: true)
                other.end(segment: 1, reason: reason, at: 60)
                try expect(other.presentation(at: 60) == .hidden, "An ordinary stop was mislabeled as a device limit")
            }
        }),
        ("duplicate starts and late ends cannot rebase or hide a new voice warning", {
            var indicator = VoiceLimitIndicator(); indicator.begin(segment: 1, at: 0, hasRC003Limit: true)
            try expect(!indicator.begin(segment: 1, at: 30, hasRC003Limit: true), "Duplicate START extended the duration")
            try expect(indicator.presentation(at: 50) == .countdown(seconds: 10, urgent: false), "Original origin was lost")
            indicator.end(segment: 1, reason: .deviceLimit, at: 60)
            indicator.begin(segment: 2, at: 61, hasRC003Limit: true)
            try expect(!indicator.cancel(segment: 1) && !indicator.end(segment: 1, reason: .deviceLimit, at: 62), "Old callback modified a replacement segment")
            try expect(indicator.presentation(at: 111) == .countdown(seconds: 10, urgent: false), "Old hiding callback lost the new warning")
        }),
        ("cancelled voice warnings cannot restart from delayed old events", {
            var indicator = VoiceLimitIndicator(); indicator.begin(segment: 9, at: 0, hasRC003Limit: true)
            indicator.cancel()
            try expect(!indicator.begin(segment: 9, at: 1, hasRC003Limit: true), "Old START revived a cancelled indicator")
            try expect(!indicator.end(segment: 9, reason: .deviceLimit, at: 60) && indicator.presentation(at: 60) == .hidden, "Old STOP revived an indicator")
            indicator.begin(segment: 10, at: 100, hasRC003Limit: true)
            try expect(indicator.presentation(at: 150) == .countdown(seconds: 10, urgent: false), "Next actual segment was blocked")
        }),
        ("unsupported devices and invalid clocks never show RC003 warnings", {
            var indicator = VoiceLimitIndicator(); indicator.begin(segment: 1, at: 0, hasRC003Limit: false)
            try expect(indicator.presentation(at: 55) == .hidden && indicator.nextUpdate(at: 55) == nil, "Unsupported source received RC003 UI")
            var invalid = VoiceLimitIndicator()
            try expect(!invalid.begin(segment: 1, at: .nan, hasRC003Limit: true), "NaN origin was accepted")
            invalid.begin(segment: 1, at: 10, hasRC003Limit: true)
            try expect(invalid.presentation(at: .infinity) == .hidden && invalid.presentation(at: 9) == .hidden, "Invalid time exposed UI")
            try expect(!invalid.end(segment: 1, reason: .deviceLimit, at: 9), "Stop before the start was accepted")
        })
    ]
}
