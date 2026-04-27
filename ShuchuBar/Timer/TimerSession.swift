import Foundation

struct ActiveFocusSession {
    let startDate: Date
    let plannedBreakDurationSeconds: Int
    let themeText: String?
    let selectedLabelID: UUID?
    let typedLabelName: String?
    var focusedSecondsUntilPause: TimeInterval = 0
    var activeSliceStartDate: Date?
}

extension TBTimer {
    func beginSessionFromDraftIfIdle() {
        guard isIdle else { return }

        let focusMinutes = sanitizeMinutes(sessionDraft.focusMinutes, min: 1, max: 999)
        let breakMinutes = sanitizeMinutes(sessionDraft.breakMinutes, min: 0, max: 999)
        let trimmedTheme = sessionDraft.themeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let typedLabelName = sessionDraft.projectLabelText.trimmingCharacters(in: .whitespacesAndNewlines)

        sessionDraft.focusMinutes = focusMinutes
        sessionDraft.breakMinutes = breakMinutes
        sessionDraft.projectLabelText = typedLabelName
        pendingSessionContext = ActiveFocusSession(
            startDate: Date(),
            plannedBreakDurationSeconds: breakMinutes * 60,
            themeText: trimmedTheme.isEmpty ? nil : trimmedTheme,
            selectedLabelID: sessionDraft.selectedLabelID,
            typedLabelName: typedLabelName.isEmpty ? nil : typedLabelName,
            focusedSecondsUntilPause: 0,
            activeSliceStartDate: nil
        )

        startFocusPhase()
    }

    func sanitizeMinutes(_ value: Int, min: Int, max: Int) -> Int {
        Swift.min(Swift.max(value, min), max)
    }

    private func parseMinutes(_ value: String) -> Int? {
        Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func applyStartSessionMinutes(focusText: String, breakText: String) {
        if let parsed = parseMinutes(focusText) {
            sessionDraft.focusMinutes = sanitizeMinutes(parsed, min: 1, max: 999)
        }
        if let parsed = parseMinutes(breakText) {
            sessionDraft.breakMinutes = sanitizeMinutes(parsed, min: 0, max: 999)
        }
        updateDisplay()
    }

    func updateDefaultFocusMinutesFromText(_ value: String) {
        if let parsed = parseMinutes(value) {
            defaultFocusMinutes = sanitizeMinutes(parsed, min: 1, max: 999)
        }
    }

    func updateDefaultBreakMinutesFromText(_ value: String) {
        if let parsed = parseMinutes(value) {
            defaultBreakMinutes = sanitizeMinutes(parsed, min: 0, max: 999)
        }
    }

    func setDraftFromDefaults() {
        sessionDraft.focusMinutes = sanitizeMinutes(defaultFocusMinutes, min: 1, max: 999)
        sessionDraft.breakMinutes = sanitizeMinutes(defaultBreakMinutes, min: 0, max: 999)
        updateDisplay()
    }

    func onProjectLabelInputChanged(_ value: String) {
        sessionDraft.projectLabelText = value
        if let exact = sessionStore.exactLabel(named: value) {
            sessionDraft.selectedLabelID = exact.id
        } else if let selectedID = sessionDraft.selectedLabelID,
                  let label = sessionStore.labels.first(where: { $0.id == selectedID }),
                  label.name != value {
            sessionDraft.selectedLabelID = nil
        }
        objectWillChange.send()
    }

    func selectProjectLabel(_ label: ProjectLabel) {
        sessionDraft.projectLabelText = label.name
        sessionDraft.selectedLabelID = label.id
        objectWillChange.send()
    }

    func suggestedProjectLabels() -> [ProjectLabel] {
        sessionStore.suggestions(for: sessionDraft.projectLabelText)
    }

    func renameProjectLabel(id: UUID, newName: String) {
        sessionStore.renameLabel(id: id, newName: newName)
    }

    func deleteProjectLabel(id: UUID) {
        sessionStore.deleteLabel(id: id)
    }

    func updateFocusSessionRecord(
        id: UUID,
        themeText: String,
        labelText: String,
        selectedLabelID: UUID?
    ) {
        sessionStore.updateSession(
            id: id,
            themeText: themeText,
            labelText: labelText,
            selectedLabelID: selectedLabelID
        )
    }

    func deleteFocusSessionRecord(id: UUID) {
        sessionStore.deleteSession(id: id)
    }

    func formatDuration(_ seconds: Int) -> String {
        let totalMinutes = max(0, seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    func beginFocusTracking() {
        guard var context = pendingSessionContext else { return }
        context.activeSliceStartDate = Date()
        activeFocusSession = context
        pendingSessionContext = nil
    }

    func pauseFocusTrackingIfNeeded() { }
    func resumeFocusTrackingIfNeeded() { }

    func finalizeFocusTracking() {
        guard var session = activeFocusSession else { return }
        let endDate = Date()

        if let activeStart = session.activeSliceStartDate {
            session.focusedSecondsUntilPause += endDate.timeIntervalSince(activeStart)
        }

        let focusedSeconds = Int(session.focusedSecondsUntilPause.rounded(.down))
        activeFocusSession = nil
        pendingSessionContext = nil

        if focusedSeconds < minimumLoggableFocusSeconds {
            return
        }

        var labelID: UUID?
        var labelNameSnapshot: String?
        if let typedLabelName = session.typedLabelName {
            let label = sessionStore.resolveOrCreateLabel(
                name: typedLabelName,
                selectedID: session.selectedLabelID
            )
            labelID = label?.id
            labelNameSnapshot = label?.name ?? typedLabelName
        }

        let record = FocusSessionRecord(
            id: UUID(),
            startedAt: session.startDate,
            endedAt: endDate,
            focusedDurationSeconds: focusedSeconds,
            plannedBreakDurationSeconds: session.plannedBreakDurationSeconds,
            themeText: session.themeText,
            labelID: labelID,
            labelNameSnapshot: labelNameSnapshot
        )
        sessionStore.appendFocusSession(record)
    }
}
