import VoiRemoteCore

func playoutClockChecks() -> [(String, () throws -> Void)] {
    [
        ("continuous PCM preserves its scheduled timeline", {
            var clock = PCMPlayoutClock()
            clock.enqueued(startFrame: 1000, frameCount: 240)
            try expect(clock.recoveryStart(currentFrame: 1000) == nil, "Buffered audio was needlessly rescheduled")
        }),
        ("underrun schedules the next PCM ahead of the current device clock", {
            var clock = PCMPlayoutClock()
            clock.enqueued(startFrame: 1000, frameCount: 240)
            let future = clock.recoveryStart(currentFrame: 6000)
            try expect(future == 6800, "Late audio kept its stale schedule")
            clock.enqueued(startFrame: future!, frameCount: 240)
            try expect(clock.recoveryStart(currentFrame: 6000) == nil, "The recovered lead was not preserved")
        }),
        ("new voice session does not inherit a previous playback clock", {
            var clock = PCMPlayoutClock()
            clock.enqueued(startFrame: 1000, frameCount: 240); clock.reset()
            try expect(clock.recoveryStart(currentFrame: 100000) == nil, "Previous session influenced the new queue start")
        }),
        ("unreadable or invalid playback time cannot produce a timestamp", {
            var clock = PCMPlayoutClock(); clock.enqueued(startFrame: 0, frameCount: 240)
            for current in [Double.nan, .infinity, -1] {
                try expect(clock.recoveryStart(currentFrame: current) == nil, "Invalid device time produced a schedule")
            }
            try expect(clock.recoveryStart(currentFrame: nil) == nil, "Missing device time produced a schedule")
        })
    ]
}
