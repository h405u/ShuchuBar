import Foundation
import AppKit

extension TBTimer {
    func startStop() {
        if isIdle {
            beginSessionFromDraftIfIdle()
        } else {
            endCurrentPhase()
        }
    }

    func endSession() {
        endCurrentPhase()
    }

    func triggerFocusShortcut() {
        if isIdle {
            beginSessionFromDraftIfIdle()
            return
        }
        if isFocusing {
            endCurrentPhase()
        }
    }

    func endBreakShortcut() {
        if isOnBreak {
            endCurrentPhase()
        }
    }

    func awakenAppShortcut() {
        NSApp.activate(ignoringOtherApps: true)
        TBStatusItem.shared.showPopover(nil)
    }

    // Legacy actions intentionally no-op in simplified mode.
    func pauseResume() { }
    func addMinutes(_ minutes: Int = 1) { _ = minutes }
    func skipInterval() { }
}
