import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let focusSession = Self("focusSession")
    static let endBreak = Self("endBreak")
    static let awakenApp = Self("awakenApp")
}

extension TBTimer {
    func setupKeyboardShortcuts() {
        KeyboardShortcuts.onKeyUp(for: .focusSession, action: triggerFocusShortcut)
        KeyboardShortcuts.onKeyUp(for: .endBreak, action: endBreakShortcut)
        KeyboardShortcuts.onKeyUp(for: .awakenApp, action: awakenAppShortcut)
    }
}
