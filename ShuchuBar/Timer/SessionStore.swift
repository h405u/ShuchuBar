import Foundation

final class SessionStore: ObservableObject {
    @Published private(set) var labels: [ProjectLabel] = []
    @Published private(set) var focusSessions: [FocusSessionRecord] = []

    private let encoder = JSONEncoder()
    private let lineEncoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lineBreak = Data("\n".utf8)
    private let fileManager = FileManager.default

    private let labelsFileName = "project_labels.json"
    private let sessionsFileName = "focus_sessions.jsonl"

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        lineEncoder.outputFormatting = [.sortedKeys]
        lineEncoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601

        loadLabels()
        loadSessions()
        pruneUnusedLabels()
    }

    func suggestions(for query: String, limit: Int = 5) -> [ProjectLabel] {
        let suggestionLabels = activeLabelsForSuggestions()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return suggestionLabels
                .sorted { $0.updatedAt > $1.updatedAt }
                .prefix(limit)
                .map { $0 }
        }

        let lower = trimmed.lowercased()
        return suggestionLabels
            .map { label in
                (label, score: score(labelName: label.name.lowercased(), query: lower))
            }
            .filter { $0.score > 0 }
            .sorted { left, right in
                if left.score != right.score {
                    return left.score > right.score
                }
                return left.0.updatedAt > right.0.updatedAt
            }
            .prefix(limit)
            .map { $0.0 }
    }

    private func activeLabelsForSuggestions() -> [ProjectLabel] {
        let usedIDs = Set(focusSessions.compactMap(\.labelID))
        guard !usedIDs.isEmpty else { return [] }

        var uniqueByLowercasedName: [String: ProjectLabel] = [:]
        for label in labels where usedIDs.contains(label.id) {
            let key = label.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }
            if let existing = uniqueByLowercasedName[key] {
                if label.updatedAt > existing.updatedAt {
                    uniqueByLowercasedName[key] = label
                }
            } else {
                uniqueByLowercasedName[key] = label
            }
        }

        return Array(uniqueByLowercasedName.values)
    }

    func exactLabel(named name: String) -> ProjectLabel? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return labels.first { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    func resolveOrCreateLabel(name: String, selectedID: UUID?) -> ProjectLabel? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let selectedID, let existing = labels.first(where: { $0.id == selectedID }) {
            if existing.name.caseInsensitiveCompare(trimmed) == .orderedSame {
                return existing
            }
        }

        if let existing = exactLabel(named: trimmed) {
            return existing
        }

        let now = Date()
        let label = ProjectLabel(id: UUID(), name: trimmed, createdAt: now, updatedAt: now)
        labels.append(label)
        saveLabels()
        return label
    }

    func renameLabel(id: UUID, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = labels.firstIndex(where: { $0.id == id }) else { return }

        if let existing = labels.first(where: { $0.id != id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            labels[index].name = existing.name
            labels[index].updatedAt = Date()
            saveLabels()
            return
        }

        labels[index].name = trimmed
        labels[index].updatedAt = Date()
        saveLabels()
    }

    func deleteLabel(id: UUID) {
        let didChangeSessions = focusSessions.contains(where: { $0.labelID == id })
        if didChangeSessions {
            focusSessions = focusSessions.map { session in
                guard session.labelID == id else { return session }
                return FocusSessionRecord(
                    id: session.id,
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    focusedDurationSeconds: session.focusedDurationSeconds,
                    plannedBreakDurationSeconds: session.plannedBreakDurationSeconds,
                    themeText: session.themeText,
                    labelID: nil,
                    labelNameSnapshot: nil
                )
            }
            saveAllSessions()
        }

        let before = labels.count
        labels.removeAll { $0.id == id }
        if labels.count != before {
            saveLabels()
        }
        pruneUnusedLabels()
    }

    func updateSession(
        id: UUID,
        themeText: String,
        labelText: String,
        selectedLabelID: UUID?
    ) {
        guard let index = focusSessions.firstIndex(where: { $0.id == id }) else { return }

        let trimmedTheme = themeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLabel = labelText.trimmingCharacters(in: .whitespacesAndNewlines)

        var labelID: UUID?
        var labelNameSnapshot: String?
        if !trimmedLabel.isEmpty {
            let label = resolveOrCreateLabel(name: trimmedLabel, selectedID: selectedLabelID)
            labelID = label?.id
            labelNameSnapshot = label?.name ?? trimmedLabel
        }

        let current = focusSessions[index]
        focusSessions[index] = FocusSessionRecord(
            id: current.id,
            startedAt: current.startedAt,
            endedAt: current.endedAt,
            focusedDurationSeconds: current.focusedDurationSeconds,
            plannedBreakDurationSeconds: current.plannedBreakDurationSeconds,
            themeText: trimmedTheme.isEmpty ? nil : trimmedTheme,
            labelID: labelID,
            labelNameSnapshot: labelNameSnapshot
        )

        saveAllSessions()
        pruneUnusedLabels()
    }

    func deleteSession(id: UUID) {
        let before = focusSessions.count
        focusSessions.removeAll { $0.id == id }
        guard focusSessions.count != before else { return }
        saveAllSessions()
        pruneUnusedLabels()
    }

    func appendFocusSession(_ record: FocusSessionRecord) {
        focusSessions.append(record)
        appendSessionLine(record)
        pruneUnusedLabels()
    }

    func statsSnapshot(calendar: Calendar = .current, now: Date = Date()) -> FocusStatsSnapshot {
        let dayInterval = calendar.dateInterval(of: .day, for: now)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let yearInterval = calendar.dateInterval(of: .year, for: now)

        return FocusStatsSnapshot(
            todayFocusedSeconds: focusedSeconds(in: dayInterval),
            weekFocusedSeconds: focusedSeconds(in: weekInterval),
            monthFocusedSeconds: focusedSeconds(in: monthInterval),
            yearFocusedSeconds: focusedSeconds(in: yearInterval),
            totalFocusedSeconds: focusSessions.reduce(0) { $0 + $1.focusedDurationSeconds }
        )
    }

    func labelStatsSnapshot(labelKey: String, calendar: Calendar = .current, now: Date = Date()) -> LabelFocusStatsSnapshot {
        let dayInterval = calendar.dateInterval(of: .day, for: now)
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        let yearInterval = calendar.dateInterval(of: .year, for: now)

        let sessions = focusSessions.filter { session in
            if labelKey == "__no_label__" {
                return session.labelID == nil
            }
            return session.labelID?.uuidString == labelKey
        }

        return LabelFocusStatsSnapshot(
            todayFocusedSeconds: focusedSeconds(in: dayInterval, sessions: sessions),
            weekFocusedSeconds: focusedSeconds(in: weekInterval, sessions: sessions),
            monthFocusedSeconds: focusedSeconds(in: monthInterval, sessions: sessions),
            yearFocusedSeconds: focusedSeconds(in: yearInterval, sessions: sessions),
            totalFocusedSeconds: sessions.reduce(0) { $0 + $1.focusedDurationSeconds }
        )
    }

    func totalByLabel() -> [LabelFocusTotal] {
        let grouped = Dictionary(grouping: focusSessions) { session in
            session.labelID?.uuidString ?? "__no_label__"
        }

        let aggregates: [(total: LabelFocusTotal, lastUsedAt: Date)] = grouped.compactMap { key, sessions in
            guard let lastUsedAt = sessions.map(\.endedAt).max() else { return nil }

            let total = sessions.reduce(0) { $0 + $1.focusedDurationSeconds }
            let name: String
            if key == "__no_label__" {
                name = "Unlabeled"
            } else if let labelID = UUID(uuidString: key),
                      let label = labels.first(where: { $0.id == labelID }) {
                name = label.name
            } else {
                name = sessions.last?.labelNameSnapshot ?? "Unknown"
            }

            return (
                total: LabelFocusTotal(id: key, labelName: name, totalFocusedSeconds: total),
                lastUsedAt: lastUsedAt
            )
        }

        return aggregates
            .sorted { left, right in
                if left.lastUsedAt != right.lastUsedAt {
                    return left.lastUsedAt > right.lastUsedAt
                }
                return left.total.labelName.localizedCaseInsensitiveCompare(right.total.labelName) == .orderedAscending
            }
            .map(\.total)
    }

    private func focusedSeconds(in interval: DateInterval?) -> Int {
        guard let interval else { return 0 }
        return focusSessions
            .filter { interval.contains($0.endedAt) }
            .reduce(0) { $0 + $1.focusedDurationSeconds }
    }

    private func focusedSeconds(in interval: DateInterval?, sessions: [FocusSessionRecord]) -> Int {
        guard let interval else { return 0 }
        return sessions
            .filter { interval.contains($0.endedAt) }
            .reduce(0) { $0 + $1.focusedDurationSeconds }
    }

    private func score(labelName: String, query: String) -> Int {
        if labelName == query { return 1000 }
        if labelName.hasPrefix(query) { return 750 }
        if labelName.contains(query) { return 500 }

        let words = labelName.split(separator: " ").map(String.init)
        if words.contains(where: { $0.hasPrefix(query) }) { return 250 }
        return 0
    }

    private func pruneUnusedLabels() {
        let usedIDs = Set(focusSessions.compactMap(\.labelID))
        let before = labels.count
        labels = labels.filter { usedIDs.contains($0.id) }
        if labels.count != before {
            saveLabels()
        }
    }

    private func loadLabels() {
        guard let labelsURL = labelsURL() else { return }
        guard fileManager.fileExists(atPath: labelsURL.path) else {
            labels = []
            return
        }

        do {
            let data = try Data(contentsOf: labelsURL)
            labels = try decoder.decode([ProjectLabel].self, from: data)
        } catch {
            print("failed to load labels: \(error)")
            labels = []
        }
    }

    private func loadSessions() {
        guard let sessionsURL = sessionsURL() else { return }
        guard fileManager.fileExists(atPath: sessionsURL.path) else {
            focusSessions = []
            return
        }

        do {
            let data = try Data(contentsOf: sessionsURL)
            guard !data.isEmpty else {
                focusSessions = []
                return
            }

            do {
                let lines = String(decoding: data, as: UTF8.self)
                    .split(separator: "\n")
                    .map(String.init)
                focusSessions = try lines.map { line in
                    let lineData = Data(line.utf8)
                    return try decoder.decode(FocusSessionRecord.self, from: lineData)
                }
            } catch {
                // Backward compatibility: accept a single JSON object or array.
                if let record = try? decoder.decode(FocusSessionRecord.self, from: data) {
                    focusSessions = [record]
                    return
                }
                if let records = try? decoder.decode([FocusSessionRecord].self, from: data) {
                    focusSessions = records
                    return
                }
                throw error
            }
        } catch {
            print("failed to load focus sessions: \(error)")
            focusSessions = []
        }
    }

    private func saveLabels() {
        guard let labelsURL = labelsURL() else { return }
        do {
            try ensureStoreDirectoryExists()
            let data = try encoder.encode(labels)
            try data.write(to: labelsURL, options: .atomic)
        } catch {
            print("failed to save labels: \(error)")
        }
    }

    private func appendSessionLine(_ record: FocusSessionRecord) {
        guard let sessionsURL = sessionsURL() else { return }
        do {
            try ensureStoreDirectoryExists()
            if !fileManager.fileExists(atPath: sessionsURL.path) {
                fileManager.createFile(atPath: sessionsURL.path, contents: nil)
            }

            guard let handle = try? FileHandle(forWritingTo: sessionsURL) else { return }
            defer { try? handle.close() }

            let data = try lineEncoder.encode(record)
            try handle.seekToEnd()
            try handle.write(contentsOf: data + lineBreak)
            try handle.synchronize()
        } catch {
            print("failed to append focus session: \(error)")
        }
    }

    private func saveAllSessions() {
        guard let sessionsURL = sessionsURL() else { return }
        do {
            try ensureStoreDirectoryExists()
            var data = Data()
            for session in focusSessions {
                data.append(try lineEncoder.encode(session))
                data.append(lineBreak)
            }
            try data.write(to: sessionsURL, options: .atomic)
        } catch {
            print("failed to save focus sessions: \(error)")
        }
    }

    private func labelsURL() -> URL? {
        storeDirectoryURL()?.appendingPathComponent(labelsFileName)
    }

    private func sessionsURL() -> URL? {
        storeDirectoryURL()?.appendingPathComponent(sessionsFileName)
    }

    private func storeDirectoryURL() -> URL? {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("ShuchuBar", isDirectory: true)
    }

    private func ensureStoreDirectoryExists() throws {
        guard let directory = storeDirectoryURL() else { return }
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}
