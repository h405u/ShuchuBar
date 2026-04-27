import Foundation

extension TBTimer {
    func getNextIntervalDuration() -> TimeInterval {
        switch phase {
        case .idle, .focus:
            return TimeInterval(max(1, sessionDraft.focusMinutes) * secondsMultiplier)
        case .breakTime:
            return TimeInterval(max(0, sessionDraft.breakMinutes) * secondsMultiplier)
        }
    }

    func startTimer(seconds: Int) {
        finishTime = Date().addingTimeInterval(TimeInterval(seconds))
        appNapPrevent.startActivity()

        let queue = DispatchQueue(label: "Timer")
        timer = DispatchSource.makeTimerSource(flags: [], queue: queue)
        timer?.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(200))
        timer?.setEventHandler(handler: onTimerTick)
        timer?.setCancelHandler(handler: onTimerCancel)
        timer?.resume()
    }

    func stopTimer() {
        guard let timer else { return }
        timer.cancel()
        self.timer = nil
        appNapPrevent.endActivity()
    }
}
