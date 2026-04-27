import Foundation

extension TBTimer {
    func startFocusPhase() {
        phase = .focus
        didNotifyFocusTimeUp = false
        focusDueTime = Date().addingTimeInterval(TimeInterval(max(1, sessionDraft.focusMinutes) * secondsMultiplier))
        player.initPlayers()
        notify.showSessionStarted()
        player.playWindup()
        beginFocusTracking()
        setStateIcon()
        startTimer(seconds: max(1, sessionDraft.focusMinutes) * secondsMultiplier)
        updateDisplay()
    }

    func endCurrentPhase() {
        switch phase {
        case .idle:
            return
        case .focus:
            finalizeFocusTracking()
            notify.showSessionEnded()
            let breakSeconds = max(0, sessionDraft.breakMinutes) * secondsMultiplier
            if breakSeconds > 0 {
                player.playDing()
                startBreakPhase(seconds: breakSeconds)
            } else {
                transitionToIdle()
                player.playDing()
            }
        case .breakTime:
            transitionToIdle()
        }
    }

    private func startBreakPhase(seconds: Int) {
        phase = .breakTime
        notify.showBreakStarted()
        setStateIcon()
        startTimer(seconds: seconds)
        updateDisplay()
    }

    private func transitionToIdle() {
        phase = .idle
        stopTimer()
        player.deinitPlayers()
        setStateIcon()
        focusDueTime = nil
        didNotifyFocusTimeUp = false
        updateDisplay()
    }

    func onTimerTick() {
        DispatchQueue.main.async { [self] in
            guard timer != nil else { return }

            switch phase {
            case .focus:
                if let focusDueTime, Date() >= focusDueTime, !didNotifyFocusTimeUp {
                    didNotifyFocusTimeUp = true
                    notify.showFocusTimeUp()
                    player.playDing()
                }
            case .breakTime:
                if (finishTime?.timeIntervalSince(Date()) ?? 0) <= 0 {
                    notify.showBreakEnded()
                    transitionToIdle()
                    player.playDing()
                    return
                }
            case .idle:
                break
            }

            updateDisplay()
        }
    }

    func onTimerCancel() {
        DispatchQueue.main.async { [self] in
            updateDisplay()
        }
    }
}
