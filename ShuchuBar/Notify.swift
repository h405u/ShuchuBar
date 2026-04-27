import SwiftUI

class TBNotify: ObservableObject {
    let system = SystemNotifyHelper()

    init() {
        system.requestPermissionIfNeeded()
    }

    func showSessionStarted() {
        system.sessionStarted()
    }

    func showFocusTimeUp() {
        system.focusTimeUp()
    }

    func showSessionEnded() {
        system.sessionEnded()
    }

    func showBreakStarted() {
        system.breakStarted()
    }

    func showBreakEnded() {
        system.breakEnded()
    }
}
