import AppKit

extension TBTimer {
    func updateDisplay() {
        updateTimeLeft()
        updateStatusBar()
    }

    func updateTimeLeft() {
        let seconds: Int
        let isOvertime: Bool

        if timer == nil {
            seconds = Int(getNextIntervalDuration())
            isOvertime = false
        } else if isFocusing, let focusDueTime {
            let delta = Int(focusDueTime.timeIntervalSince(Date()).rounded(.down))
            if delta >= 0 {
                seconds = delta
                isOvertime = false
            } else {
                seconds = abs(delta)
                isOvertime = true
            }
        } else {
            let delta = Int((finishTime?.timeIntervalSince(Date()) ?? 0).rounded(.down))
            seconds = max(0, delta)
            isOvertime = false
        }

        if isOvertime {
            switch menuBarTimeStyle {
            case .clock:
                timeLeftString = "+" + formatClock(seconds: seconds)
            case .words:
                timeLeftString = "+" + formatOvertimeWords(seconds: seconds)
            }
            return
        }

        switch menuBarTimeStyle {
        case .clock:
            timeLeftString = formatClock(seconds: seconds)
        case .words:
            timeLeftString = formatWords(seconds: seconds)
        }
    }

    func updateStatusBar() {
        switch showTimerMode {
        case .disabled:
            setTitle(nil)
        case .running:
            setTitle(timer == nil ? nil : timeLeftString)
        case .always:
            setTitle(timeLeftString)
        }
    }

    private func formatClock(seconds: Int) -> String {
        let value = max(0, seconds)
        let mins = value / 60
        let secs = value % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func formatWords(seconds: Int) -> String {
        let value = max(0, seconds)
        if value < 60 {
            return String(format: "%02d sec", value)
        }
        let mins = value / 60
        if value < 3600 {
            return String(format: "%02d min", mins)
        }
        let hours = mins / 60
        let restMins = mins % 60
        return String(format: "%02dh %02dm", hours, restMins)
    }

    private func formatOvertimeWords(seconds: Int) -> String {
        let value = max(0, seconds)
        let mins = max(1, Int(ceil(Double(value) / 60.0)))
        return String(format: "%02d min", mins)
    }

    func setTitle(_ title: String?) {
        TBStatusItem.shared.setTitle(title: title)
    }

    func setStateIcon() {
        TBStatusItem.shared.setIcon(name: .idle)
    }
}
