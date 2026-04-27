import Foundation

struct SessionDraft {
    var themeText: String = ""
    var focusMinutes: Int = 25
    var breakMinutes: Int = 5
    var projectLabelText: String = ""
    var selectedLabelID: UUID?
}

struct ProjectLabel: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
}

struct FocusSessionRecord: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let focusedDurationSeconds: Int
    let plannedBreakDurationSeconds: Int
    let themeText: String?
    let labelID: UUID?
    let labelNameSnapshot: String?
}

struct LabelFocusTotal: Identifiable {
    let id: String
    let labelName: String
    let totalFocusedSeconds: Int
}

struct FocusStatsSnapshot {
    let todayFocusedSeconds: Int
    let weekFocusedSeconds: Int
    let monthFocusedSeconds: Int
    let yearFocusedSeconds: Int
    let totalFocusedSeconds: Int
}

struct LabelFocusStatsSnapshot {
    let todayFocusedSeconds: Int
    let weekFocusedSeconds: Int
    let monthFocusedSeconds: Int
    let yearFocusedSeconds: Int
    let totalFocusedSeconds: Int
}
