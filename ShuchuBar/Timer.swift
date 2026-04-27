import SwiftUI
import AppKit

enum ShowTimerMode: String, CaseIterable, DropdownDescribable {
    case disabled, running, always
}

enum MenuBarTimeStyle: String, CaseIterable, DropdownDescribable {
    case clock, words
}

class TBTimer: ObservableObject {
    @AppStorage("showTimerMode") var showTimerMode = Default.showTimerMode
    @AppStorage("menuBarTimeStyle") var menuBarTimeStyle = Default.menuBarTimeStyle
    @AppStorage("grayBackgroundOpacity") var grayBackgroundOpacity = Default.grayBackgroundOpacity
    @AppStorage("defaultFocusMinutes") var defaultFocusMinutes = 25
    @AppStorage("defaultBreakMinutes") var defaultBreakMinutes = 5

    #if DEBUG
    var secondsMultiplier: Int { 60 }
    #else
    var secondsMultiplier: Int { 60 }
    #endif

    public var player = TBPlayer()
    public let notify = TBNotify()
    let minimumLoggableFocusSeconds: Int = 5 * 60

    var finishTime: Date?
    var focusDueTime: Date?
    var didNotifyFocusTimeUp = false
    var timerFormatter = DateComponentsFormatter()
    let appNapPrevent = AppNapPrevent()
    @Published var timeLeftString: String = ""
    @Published var timer: DispatchSourceTimer?
    @Published var phase: TBTimerPhase = .idle
    @Published var sessionDraft = SessionDraft()
    @Published var sessionStore = SessionStore()

    var pendingSessionContext: ActiveFocusSession?
    var activeFocusSession: ActiveFocusSession?

    var isIdle: Bool {
        phase == .idle
    }

    var isFocusing: Bool {
        phase == .focus
    }

    var isOnBreak: Bool {
        phase == .breakTime
    }

    var isTiming: Bool {
        isFocusing || isOnBreak
    }

    init() {
        timerFormatter.unitsStyle = .positional

        setupKeyboardShortcuts()

        let aem: NSAppleEventManager = NSAppleEventManager.shared()
        aem.setEventHandler(self,
                            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
                            forEventClass: AEEventClass(kInternetEventClass),
                            andEventID: AEEventID(kAEGetURL))

        setDraftFromDefaults()
    }
}
