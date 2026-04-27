import SwiftUI

enum ChildView {
    case settings, stats, sessions
}

private let sectionFixedHeight: CGFloat = 220 
private let popoverHorizontalPadding: CGFloat = 6

struct TBPopoverView: View {
    @ObservedObject var timer = TBTimer()
    @State private var activeChildView = ChildView.settings
    @State private var focusMinutesText = ""
    @State private var breakMinutesText = ""
    @State private var startFormInitialized = false
    @State private var startSuggestionIndex = -1
    @FocusState private var isThemeFieldFocused: Bool

    private func getLocalizedWidth() -> CGFloat {
        let widthString = NSLocalizedString("View.width", comment: "Width for the view")
        let baseWidth = CGFloat(Double(widthString) ?? 255)
        return uiSize(baseWidth, macOS26: baseWidth + 50)
    }

    var body: some View {
        let popoverWidth = getLocalizedWidth()
        let sectionFixedWidth = popoverWidth

        VStack(alignment: .leading, spacing: 10) {
            Group {
                if timer.isIdle {
                    startSessionView
                } else {
                    activeSessionView
                }
            }
            .frame(width: sectionFixedWidth, alignment: .leading)

            Picker("", selection: $activeChildView) {
                Text("Settings").tag(ChildView.settings)
                Text("Stats").tag(ChildView.stats)
                Text("Sessions").tag(ChildView.sessions)
            }
            .labelsHidden()
            .frame(width: sectionFixedWidth, alignment: .leading)
            .pickerStyle(.segmented)

            GroupBox {
                switch activeChildView {
                case .settings:
                    SettingsView()
                        .environmentObject(timer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                case .stats:
                    StatsView(timer: timer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                case .sessions:
                    SessionsView(timer: timer)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(width: sectionFixedWidth, height: sectionFixedHeight, alignment: .topLeading)

            Group {
                #if SPARKLE
                Button {
                    TBStatusItem.shared.checkForUpdates()
                } label: {
                    Text(NSLocalizedString("View.checkForUpdates.label",
                                           comment: "Check for Updates label"))
                    Spacer()
                    Text("⌘ U").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("u")
                #endif

                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationVersion: "",
                        .version: ""
                    ])
                } label: {
                    Text(NSLocalizedString("View.about.label",
                                           comment: "About label"))
                    Spacer()
                }
                .buttonStyle(.plain)

                Button {
                    NSApplication.shared.terminate(self)
                } label: {
                    Text(NSLocalizedString("View.quit.label",
                                           comment: "Quit label"))
                    Spacer()
                    Text("⌘ Q").foregroundColor(Color.gray)
                }
                .buttonStyle(.plain)
                .keyboardShortcut("q")
            }
        }
        .frame(width: popoverWidth)
        .padding(popoverHorizontalPadding)
        .onChange(of: timer.phase) { phase in
            if phase == .idle {
                focusThemeFieldIfIdle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .tbPopoverDidShow)) { _ in
            focusThemeFieldIfIdle()
        }
    }

    private var startSessionView: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Start Session")
                .font(.headline)

            TextField("Theme (optional)", text: $timer.sessionDraft.themeText)
                .focused($isThemeFieldFocused)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Text("Focus (min)")
                    .frameInfinityLeading()
                TextField("", text: $focusMinutesText)
                    .frame(width: 64, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: focusMinutesText) { _ in
                        syncStartSessionMinuteDraftFromInputs()
                    }
                    .onSubmit {
                        commitStartSessionMinuteInputs()
                    }
            }

            HStack {
                Text("Break (min)")
                    .frameInfinityLeading()
                TextField("", text: $breakMinutesText)
                    .frame(width: 64, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: breakMinutesText) { _ in
                        syncStartSessionMinuteDraftFromInputs()
                    }
                    .onSubmit {
                        commitStartSessionMinuteInputs()
                    }
            }

            let suggestions = startLabelSuggestions

            KeyAwareTextField(
                placeholder: "Project label (optional)",
                text: Binding(
                    get: { timer.sessionDraft.projectLabelText },
                    set: { timer.onProjectLabelInputChanged($0) }
                ),
                onArrowUp: {
                    guard !suggestions.isEmpty else { return }
                    if startSuggestionIndex <= 0 {
                        startSuggestionIndex = suggestions.count - 1
                    } else {
                        startSuggestionIndex -= 1
                    }
                },
                onArrowDown: {
                    guard !suggestions.isEmpty else { return }
                    startSuggestionIndex = (startSuggestionIndex + 1) % suggestions.count
                },
                onReturn: {
                    if !suggestions.isEmpty, startSuggestionIndex >= 0, startSuggestionIndex < suggestions.count {
                        let highlighted = suggestions[startSuggestionIndex]
                        if timer.sessionDraft.selectedLabelID != highlighted.id ||
                            timer.sessionDraft.projectLabelText != highlighted.name {
                            timer.selectProjectLabel(highlighted)
                            return .handled
                        }
                    }
                    startSuggestionIndex = -1
                    timer.onProjectLabelInputChanged(timer.sessionDraft.projectLabelText)
                    return .handledAndEndEditing
                }
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: timer.sessionDraft.projectLabelText) { _ in
                startSuggestionIndex = -1
            }

            if !suggestions.isEmpty && !timer.sessionDraft.projectLabelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, label in
                        Button {
                            timer.selectProjectLabel(label)
                            startSuggestionIndex = index
                        } label: {
                            HStack {
                                Image(systemName: "tag")
                                Text(label.name)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 2)
                        .background(startSuggestionIndex == index ? Color.accentColor.opacity(0.16) : Color.clear)
                        .cornerRadius(4)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.12))
                .cornerRadius(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                NSApp.keyWindow?.makeFirstResponder(nil)
                DispatchQueue.main.async {
                    commitStartSessionMinuteInputs()
                    timer.beginSessionFromDraftIfIdle()
                    TBStatusItem.shared.closePopover(nil)
                }
            } label: {
                HStack {
                    Text(Image(systemName: "play.fill"))
                    Text("Start Session")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .onAppear {
            if startFormInitialized { return }
            focusMinutesText = "\(timer.sessionDraft.focusMinutes)"
            breakMinutesText = "\(timer.sessionDraft.breakMinutes)"
            startFormInitialized = true
            focusThemeFieldIfIdle()
        }
    }

    private var startLabelSuggestions: [ProjectLabel] {
        timer.suggestedProjectLabels()
            .filter { $0.id != timer.sessionDraft.selectedLabelID || $0.name != timer.sessionDraft.projectLabelText }
            .prefix(4)
            .map { $0 }
    }

    private var activeSessionView: some View {
        Button {
            timer.endSession()
            TBStatusItem.shared.closePopover(nil)
        } label: {
            HStack {
                Text(Image(systemName: "stop.fill"))
                Text("End")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
            .background(Color.red)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private func focusThemeFieldIfIdle() {
        guard timer.isIdle else { return }
        DispatchQueue.main.async {
            isThemeFieldFocused = true
        }
    }

    private func commitStartSessionMinuteInputs() {
        timer.applyStartSessionMinutes(
            focusText: focusMinutesText,
            breakText: breakMinutesText
        )
        focusMinutesText = "\(timer.sessionDraft.focusMinutes)"
        breakMinutesText = "\(timer.sessionDraft.breakMinutes)"
    }

    private func syncStartSessionMinuteDraftFromInputs() {
        timer.applyStartSessionMinutes(
            focusText: focusMinutesText,
            breakText: breakMinutesText
        )
    }
}

private struct StatsView: View {
    @ObservedObject var timer: TBTimer
    @State private var selectedLabelKey: String?
    @State private var editingLabelID: UUID?
    @State private var editingLabelText: String = ""
    @State private var pendingDeleteLabelID: UUID?
    @State private var pendingDeleteLabelName: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let stats = timer.sessionStore.statsSnapshot()
            let totalByLabel = timer.sessionStore.totalByLabel()
            let selectedLabel = totalByLabel.first(where: { $0.id == selectedLabelKey })
            let title = selectedLabel.map { "Focused Time @ \($0.labelName)" } ?? "Focused Time"
            let displayedStats = selectedLabel
                .map { timer.sessionStore.labelStatsSnapshot(labelKey: $0.id) }
                .map {
                    (
                        today: $0.todayFocusedSeconds,
                        week: $0.weekFocusedSeconds,
                        total: $0.totalFocusedSeconds
                    )
                } ?? (
                    today: stats.todayFocusedSeconds,
                    week: stats.weekFocusedSeconds,
                    total: stats.totalFocusedSeconds
                )

            Text(title)
                .font(.subheadline)
            row(label: "Today", value: timer.formatDuration(displayedStats.today))
            row(label: "This Week", value: timer.formatDuration(displayedStats.week))
            row(label: "Total", value: timer.formatDuration(displayedStats.total))

            Divider()
            Text("Total by Label")
                .font(.subheadline)

            if totalByLabel.isEmpty {
                Text("No logged sessions yet")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(totalByLabel) { total in
                            Button {
                                selectedLabelKey = (selectedLabelKey == total.id) ? nil : total.id
                            } label: {
                                HStack {
                                    Text(total.labelName)
                                        .underline(selectedLabelKey == total.id)
                                    Spacer()
                                    Text(timer.formatDuration(total.totalFocusedSeconds))
                                        .font(.system(.body).monospacedDigit())
                                        .foregroundColor(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if let labelID = UUID(uuidString: total.id),
                                   total.id != "__no_label__" {
                                    Button("Edit label") {
                                        editingLabelID = labelID
                                        editingLabelText = total.labelName
                                    }
                                    Button("Delete label", role: .destructive) {
                                        pendingDeleteLabelID = labelID
                                        pendingDeleteLabelName = total.labelName
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if let editingLabelID {
                Divider()
                Text("Edit label")
                    .font(.subheadline)
                HStack {
                    KeyAwareTextField(
                        placeholder: "Label",
                        text: $editingLabelText,
                        onReturn: {
                            timer.renameProjectLabel(id: editingLabelID, newName: editingLabelText)
                            self.editingLabelID = nil
                            timer.sessionStore.objectWillChange.send()
                            return .handledAndEndEditing
                        }
                    )
                    Button("Save") {
                        timer.renameProjectLabel(id: editingLabelID, newName: editingLabelText)
                        self.editingLabelID = nil
                        timer.sessionStore.objectWillChange.send()
                    }
                    Button("Cancel") {
                        self.editingLabelID = nil
                    }
                }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Delete label \"\(pendingDeleteLabelName)\"?", isPresented: Binding(
            get: { pendingDeleteLabelID != nil },
            set: { if !$0 { pendingDeleteLabelID = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let id = pendingDeleteLabelID else { return }
                timer.deleteProjectLabel(id: id)
                selectedLabelKey = nil
                if editingLabelID == id {
                    editingLabelID = nil
                }
                pendingDeleteLabelID = nil
                // Force immediate redraw of list and details after store mutation.
                timer.sessionStore.objectWillChange.send()
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteLabelID = nil
            }
        } message: {
            Text("Sessions on this label will become unlabeled.")
        }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.body).monospacedDigit())
                .foregroundColor(.secondary)
        }
    }
}

private struct SessionDayGroup: Identifiable {
    let id: Date
    let title: String
    let sessions: [FocusSessionRecord]
}

private struct SessionsView: View {
    @ObservedObject var timer: TBTimer
    @State private var editingSessionID: UUID?
    @State private var editingThemeText: String = ""
    @State private var editingLabelText: String = ""
    @State private var editingSelectedLabelID: UUID?
    @State private var editingSuggestionIndex = -1
    @State private var pendingDeleteSessionID: UUID?
    @State private var pendingDeleteSessionTheme: String = ""

    private var dayGroups: [SessionDayGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: timer.sessionStore.focusSessions) { session in
            calendar.startOfDay(for: session.startedAt)
        }

        return grouped
            .map { day, sessions in
                SessionDayGroup(
                    id: day,
                    title: day.formatted(date: .abbreviated, time: .omitted),
                    sessions: sessions.sorted { $0.startedAt > $1.startedAt }
                )
            }
            .sorted { $0.id > $1.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if dayGroups.isEmpty {
                Text("No logged sessions yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 5) {
                        ForEach(dayGroups) { group in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.title)
                                    .font(.subheadline)
                                ForEach(group.sessions) { session in
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(sessionRowTitle(for: session))
                                            .fixedSize(horizontal: false, vertical: true)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .layoutPriority(1)
                                        Text("\(max(1, session.focusedDurationSeconds / 60))m")
                                            .font(.system(.body).monospacedDigit())
                                            .foregroundColor(.secondary)
                                            .fixedSize()
                                    }
                                    .contextMenu {
                                        Button("Edit session") {
                                            beginEditing(session)
                                        }
                                        Button("Delete session", role: .destructive) {
                                            pendingDeleteSessionID = session.id
                                            pendingDeleteSessionTheme = (session.themeText?.isEmpty == false) ? (session.themeText ?? "") : "Untitled"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            if let editingSessionID,
               let session = timer.sessionStore.focusSessions.first(where: { $0.id == editingSessionID }) {
                Divider()
                Text("Edit session")
                    .font(.subheadline)

                KeyAwareTextField(
                    placeholder: "Theme",
                    text: $editingThemeText,
                    onReturn: {
                        saveEditedSession(sessionID: session.id)
                        return .handledAndEndEditing
                    }
                )

                KeyAwareTextField(
                    placeholder: "Project label (optional)",
                    text: Binding(
                        get: { editingLabelText },
                        set: { updateEditingLabelText($0) }
                    ),
                    onArrowUp: {
                        guard !editingSuggestions.isEmpty else { return }
                        if editingSuggestionIndex <= 0 {
                            editingSuggestionIndex = editingSuggestions.count - 1
                        } else {
                            editingSuggestionIndex -= 1
                        }
                    },
                    onArrowDown: {
                        guard !editingSuggestions.isEmpty else { return }
                        editingSuggestionIndex = (editingSuggestionIndex + 1) % editingSuggestions.count
                    },
                    onReturn: {
                        if !editingSuggestions.isEmpty, editingSuggestionIndex >= 0, editingSuggestionIndex < editingSuggestions.count {
                            let selected = editingSuggestions[editingSuggestionIndex]
                            if editingSelectedLabelID != selected.id || editingLabelText != selected.name {
                                editingLabelText = selected.name
                                editingSelectedLabelID = selected.id
                                return .handled
                            }
                        }
                        saveEditedSession(sessionID: session.id)
                        return .handledAndEndEditing
                    }
                )
                .onChange(of: editingLabelText) { _ in
                    editingSuggestionIndex = -1
                }

                let suggestions = editingSuggestions
                if !suggestions.isEmpty && !editingLabelText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, label in
                            Button {
                                editingLabelText = label.name
                                editingSelectedLabelID = label.id
                                editingSuggestionIndex = index
                            } label: {
                                HStack {
                                    Image(systemName: "tag")
                                    Text(label.name)
                                    Spacer()
                                }
                            }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 2)
                        .background(editingSuggestionIndex == index ? Color.accentColor.opacity(0.16) : Color.clear)
                            .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.12))
                    .cornerRadius(6)
                }

                HStack {
                    Button("Save") {
                        saveEditedSession(sessionID: session.id)
                    }
                    Button("Cancel") {
                        self.editingSessionID = nil
                    }
                }
            }
        }
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Delete session \"\(pendingDeleteSessionTheme)\"?", isPresented: Binding(
            get: { pendingDeleteSessionID != nil },
            set: { if !$0 { pendingDeleteSessionID = nil } }
        )) {
            Button("Delete", role: .destructive) {
                guard let id = pendingDeleteSessionID else { return }
                timer.deleteFocusSessionRecord(id: id)
                if editingSessionID == id {
                    editingSessionID = nil
                }
                pendingDeleteSessionID = nil
                timer.sessionStore.objectWillChange.send()
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteSessionID = nil
            }
        } message: {
            Text("This recorded session will be permanently removed.")
        }
    }

    private var editingSuggestions: [ProjectLabel] {
        timer.sessionStore.suggestions(for: editingLabelText)
            .filter {
                $0.id != editingSelectedLabelID || $0.name != editingLabelText
            }
            .prefix(4)
            .map { $0 }
    }

    private func beginEditing(_ session: FocusSessionRecord) {
        editingSessionID = session.id
        editingThemeText = session.themeText ?? ""
        editingLabelText = session.labelNameSnapshot ?? ""
        editingSelectedLabelID = session.labelID
        editingSuggestionIndex = -1
    }

    private func updateEditingLabelText(_ value: String) {
        editingLabelText = value
        if let exact = timer.sessionStore.exactLabel(named: value) {
            editingSelectedLabelID = exact.id
            return
        }

        if let selected = editingSelectedLabelID,
           let label = timer.sessionStore.labels.first(where: { $0.id == selected }),
           label.name != value {
            editingSelectedLabelID = nil
        }
    }

    private func saveEditedSession(sessionID: UUID) {
        timer.updateFocusSessionRecord(
            id: sessionID,
            themeText: editingThemeText,
            labelText: editingLabelText,
            selectedLabelID: editingSelectedLabelID
        )
        self.editingSessionID = nil
        timer.sessionStore.objectWillChange.send()
    }

    private func sessionRowTitle(for session: FocusSessionRecord) -> String {
        let currentLabelName = labelName(for: session)
        let theme = (session.themeText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !theme.isEmpty else {
            return "@ \(currentLabelName)"
        }
        return "\(theme) @ \(currentLabelName)"
    }

    private func labelName(for session: FocusSessionRecord) -> String {
        if let labelID = session.labelID,
           let label = timer.sessionStore.labels.first(where: { $0.id == labelID }) {
            return label.name
        }

        let snapshot = (session.labelNameSnapshot ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !snapshot.isEmpty {
            return snapshot
        }
        return "Unlabeled"
    }
}

private struct KeyAwareTextField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onArrowUp: () -> Void = { }
    var onArrowDown: () -> Void = { }
    var onReturn: () -> KeyAwareReturnAction = { .passthrough }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.placeholderString = placeholder
        textField.delegate = context.coordinator
        context.coordinator.onArrowUp = onArrowUp
        context.coordinator.onArrowDown = onArrowDown
        context.coordinator.onReturn = onReturn
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.onArrowUp = onArrowUp
        context.coordinator.onArrowDown = onArrowDown
        context.coordinator.onReturn = onReturn
    }

    final class Coordinator: NSObject, NSTextFieldDelegate, NSControlTextEditingDelegate {
        @Binding private var text: String
        var onArrowUp: () -> Void = { }
        var onArrowDown: () -> Void = { }
        var onReturn: () -> KeyAwareReturnAction = { .passthrough }

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            text = textField.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveUp(_:)):
                onArrowUp()
                return true
            case #selector(NSResponder.moveDown(_:)):
                onArrowDown()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                let action = onReturn()
                switch action {
                case .passthrough:
                    return false
                case .handled:
                    return true
                case .handledAndEndEditing:
                    textView.window?.makeFirstResponder(nil)
                    return true
                }
            default:
                return false
            }
        }
    }
}

private enum KeyAwareReturnAction {
    case passthrough
    case handled
    case handledAndEndEditing
}
