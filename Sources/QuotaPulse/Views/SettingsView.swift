import AppKit
import SwiftUI

struct SettingsView: View {
    let language: LanguageSettings
    let notificationService: QuotaNotificationService
    let store: QuotaStore
    let localNotificationHTTPToken: String
    @State private var loginItem = LoginItemManager()
    @State private var reminders: [DailyReminderConfiguration]
    @State private var reminderStatusKey: String?
    @State private var reminderStatusIsError = false
    @State private var quotaNotificationConfiguration: QuotaNotificationConfiguration
    @State private var quotaNotificationStatusKey: String?
    @State private var quotaNotificationStatusIsError = false
    @State private var weeklyQuotaPlanConfiguration: WeeklyQuotaPlanConfiguration
    @State private var weeklyQuotaPlanStatusKey: String?
    @State private var notificationAuthorizationState = NotificationAuthorizationState.unknown
    @State private var deepSeekConfiguration: DeepSeekBalanceConfiguration
    @State private var deepSeekAPIKey = ""
    @State private var deepSeekAPIKeyIsVisible = false
    @State private var deepSeekAPIKeyShouldSelectAll = false
    @State private var deepSeekStatusKey: String?
    @State private var deepSeekStatusIsError = false
    @Environment(\.scenePhase) private var scenePhase

    init(language: LanguageSettings, notificationService: QuotaNotificationService, store: QuotaStore, localNotificationHTTPToken: String = LocalNotificationHTTPTokenStore.loadOrCreate()) {
        self.language = language
        self.notificationService = notificationService
        self.store = store
        self.localNotificationHTTPToken = localNotificationHTTPToken
        _reminders = State(initialValue: ReminderListPolicy.preparingForDisplay(
            DailyReminderPreferences.loadAll()
        ))
        _quotaNotificationConfiguration = State(initialValue: QuotaNotificationPreferences.load())
        _weeklyQuotaPlanConfiguration = State(initialValue: WeeklyQuotaPlanPreferences.load())
        _deepSeekConfiguration = State(initialValue: DeepSeekBalanceConfiguration.load())
        _deepSeekAPIKey = State(initialValue: DeepSeekAPIKeyStore.load() ?? "")
    }

    var body: some View {
        Form {
            Section(language.text("settings.quotaNotification")) {
                notificationAuthorizationRow

                Picker(
                    language.text("settings.quotaNotification.mode"),
                    selection: $quotaNotificationConfiguration.mode
                ) {
                    Text(language.text("settings.quotaNotification.mode.single"))
                        .tag(QuotaNotificationConfiguration.Mode.singleStage)
                    Text(language.text("settings.quotaNotification.mode.twoStage"))
                        .tag(QuotaNotificationConfiguration.Mode.twoStage)
                }
                .pickerStyle(.segmented)

                if quotaNotificationConfiguration.mode == .singleStage {
                    percentField(
                        language.text("settings.quotaNotification.interval"),
                        value: $quotaNotificationConfiguration.firstIntervalPercent
                    )
                } else {
                    percentField(
                        language.text("settings.quotaNotification.breakpoint"),
                        value: $quotaNotificationConfiguration.breakpointPercent
                    )
                    percentField(
                        language.text("settings.quotaNotification.firstInterval"),
                        value: $quotaNotificationConfiguration.firstIntervalPercent
                    )
                    percentField(
                        language.text("settings.quotaNotification.secondInterval"),
                        value: $quotaNotificationConfiguration.secondIntervalPercent
                    )
                }

                HStack {
                    Button(language.text("settings.quotaNotification.save")) {
                        saveQuotaNotificationConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                    if let quotaNotificationStatusKey {
                        Label(
                            language.text(quotaNotificationStatusKey),
                            systemImage: quotaNotificationStatusIsError
                                ? "exclamationmark.triangle.fill"
                                : "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(quotaNotificationStatusIsError ? Color.orange : Color.green)
                    }
                }

                Text(language.text("settings.quotaNotification.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(language.text("settings.weeklyPlan")) {
                Toggle(isOn: $weeklyQuotaPlanConfiguration.excludesWeekends) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(language.text("settings.weeklyPlan.excludeWeekends"))
                        Text(language.text("settings.weeklyPlan.excludeWeekends.detail"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Button(language.text("settings.weeklyPlan.save")) {
                        saveWeeklyQuotaPlanConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                    if let weeklyQuotaPlanStatusKey {
                        Label(
                            language.text(weeklyQuotaPlanStatusKey),
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(Color.green)
                    }
                }
            }

            Section(language.text("settings.deepSeek")) {
                Toggle(isOn: $deepSeekConfiguration.isEnabled) {
                    Text(language.text("settings.deepSeek.enabled"))
                }
                HStack(spacing: 12) {
                    Text(language.text("settings.deepSeek.apiKey"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 8) {
                        if deepSeekAPIKeyIsVisible {
                            SelectableAPIKeyTextField(
                                text: $deepSeekAPIKey,
                                shouldSelectAll: $deepSeekAPIKeyShouldSelectAll
                            )
                            .frame(maxWidth: .infinity, minHeight: 28)
                        } else {
                            SecureField("", text: $deepSeekAPIKey)
                                .labelsHidden()
                                .textFieldStyle(.roundedBorder)
                                .frame(maxWidth: .infinity)
                        }

                        Button {
                            deepSeekAPIKeyIsVisible.toggle()
                            if deepSeekAPIKeyIsVisible {
                                deepSeekAPIKeyShouldSelectAll = true
                            }
                        } label: {
                            Image(systemName: deepSeekAPIKeyIsVisible ? "eye.slash" : "eye")
                                .imageScale(.medium)
                                .frame(width: 16, height: 16)
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                        .help(
                            language.text(
                                deepSeekAPIKeyIsVisible
                                    ? "settings.deepSeek.apiKey.hide"
                                    : "settings.deepSeek.apiKey.show"
                            )
                        )
                    }
                    .frame(maxWidth: 360)
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text(language.text("settings.deepSeek.curlTemplate"))
                        .font(.subheadline.weight(.medium))
                    TextEditor(text: $deepSeekConfiguration.curlTemplate)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 70)
                        .padding(4)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.secondary.opacity(0.25))
                        }
                }
                HStack {
                    Button(language.text("settings.deepSeek.save")) {
                        saveDeepSeekConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                    if let deepSeekStatusKey {
                        Label(
                            language.text(deepSeekStatusKey),
                            systemImage: deepSeekStatusIsError
                                ? "exclamationmark.triangle.fill"
                                : "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(deepSeekStatusIsError ? Color.orange : Color.green)
                    }
                }
                Text(language.text("settings.deepSeek.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(language.text("settings.localNotificationAPI")) {
                LabeledContent(language.text("settings.localNotificationAPI.endpoint"), value: "http://127.0.0.1:\(LocalNotificationHTTPAPI.port)/v1/notifications")
                HStack(spacing: 12) {
                    Text(language.text("settings.localNotificationAPI.token"))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(localNotificationHTTPToken)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                    Button(language.text("settings.localNotificationAPI.copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(localNotificationHTTPToken, forType: .string)
                    }
                }
                Text(language.text("settings.localNotificationAPI.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if reminders.isEmpty {
                    ContentUnavailableView(
                        language.text("settings.reminder.empty"),
                        systemImage: "bell.badge"
                    )
                    .frame(maxWidth: .infinity, minHeight: 90)
                } else {
                    ForEach($reminders) { $reminder in
                        DailyReminderEditor(
                            language: language,
                            reminder: $reminder,
                            onDelete: { deleteReminder(id: reminder.id) }
                        )
                    }
                }

                HStack {
                    Button(language.text("settings.reminder.save")) { saveDailyReminders() }
                        .buttonStyle(.borderedProminent)
                        .disabled(reminders.isEmpty)
                    Spacer()
                    if let reminderStatusKey {
                        Label(
                            language.text(reminderStatusKey),
                            systemImage: reminderStatusIsError
                                ? "exclamationmark.triangle.fill"
                                : "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(reminderStatusIsError ? Color.orange : Color.green)
                    }
                }

                Text(language.text("settings.reminder.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                HStack {
                    Text(language.text("settings.reminder"))
                    Spacer()
                    Button(action: addReminder) {
                        Label(language.text("settings.reminder.add"), systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Section(language.text("settings.general")) {
                Picker(
                    language.text("settings.language"),
                    selection: Binding(
                        get: { language.language },
                        set: { language.language = $0 }
                    )
                ) {
                    Text(language.text("settings.chinese")).tag(AppLanguage.simplifiedChinese)
                    Text(language.text("settings.english")).tag(AppLanguage.english)
                }
                .pickerStyle(.segmented)

                Toggle(isOn: Binding(
                    get: { loginItem.isRegistered },
                    set: { loginItem.setEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(language.text("settings.launchAtLogin"))
                        Text(language.text("settings.launchAtLogin.detail"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent(language.text("settings.systemStatus"), value: loginItem.statusText(language: language))

                if loginItem.requiresApproval {
                    HStack(spacing: 10) {
                        Label(language.text("settings.approvalRequired"), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button(language.text("settings.openLoginItems")) { loginItem.openSystemSettings() }
                    }
                    .font(.caption)
                }

                if let errorMessage = loginItem.errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(language.text("settings.data")) {
                LabeledContent(language.text("settings.quotaSource"), value: "Codex + Claude Direct")
                LabeledContent(language.text("settings.refreshRate"), value: language.text("settings.refreshRate.value"))
                Text(language.text("settings.privacy"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 620, height: 760)
        .onAppear { loginItem.refresh() }
        .task { await refreshNotificationAuthorization(requestIfNeeded: true) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                loginItem.refresh()
                Task { await refreshNotificationAuthorization(requestIfNeeded: false) }
            }
        }
    }

    private var notificationAuthorizationRow: some View {
        HStack(spacing: 12) {
            Label(
                language.text(notificationAuthorizationStatusKey),
                systemImage: notificationAuthorizationState == .authorized
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill"
            )
            .foregroundStyle(notificationAuthorizationState == .authorized ? Color.green : Color.orange)
            Spacer()
            switch notificationAuthorizationState {
            case .denied:
                Button(language.text("settings.notificationPermission.openSettings")) {
                    notificationService.openSystemNotificationSettings()
                }
            case .notDetermined:
                Button(language.text("settings.notificationPermission.request")) {
                    Task { await refreshNotificationAuthorization(requestIfNeeded: true) }
                }
            case .unknown, .authorized:
                EmptyView()
            }
        }
        .font(.caption)
    }

    private var notificationAuthorizationStatusKey: String {
        switch notificationAuthorizationState {
        case .unknown: "settings.notificationPermission.checking"
        case .notDetermined: "settings.notificationPermission.notDetermined"
        case .denied: "settings.notificationPermission.denied"
        case .authorized: "settings.notificationPermission.authorized"
        }
    }

    private func refreshNotificationAuthorization(requestIfNeeded: Bool) async {
        notificationAuthorizationState = requestIfNeeded
            ? await notificationService.requestAuthorizationIfNeeded()
            : await notificationService.authorizationState()
    }

    private func percentField(_ title: String, value: Binding<Int>) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            TextField("", value: value, format: .number)
                .labelsHidden()
                .accessibilityLabel(title)
                .textFieldStyle(.roundedBorder)
                .frame(width: 72)
                .multilineTextAlignment(.trailing)
            Text("%")
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)
        }
        .frame(minHeight: 28)
    }

    private func saveQuotaNotificationConfiguration() {
        guard quotaNotificationConfiguration.isValid else {
            quotaNotificationStatusKey = "settings.quotaNotification.status.invalid"
            quotaNotificationStatusIsError = true
            return
        }
        QuotaNotificationPreferences.save(quotaNotificationConfiguration)
        quotaNotificationStatusKey = "settings.quotaNotification.status.saved"
        quotaNotificationStatusIsError = false
    }

    private func saveWeeklyQuotaPlanConfiguration() {
        store.updateWeeklyQuotaPlan(weeklyQuotaPlanConfiguration)
        weeklyQuotaPlanStatusKey = "settings.weeklyPlan.status.saved"
    }

    private func saveDeepSeekConfiguration() {
        switch DeepSeekSettingsValidation.validate(
            isEnabled: deepSeekConfiguration.isEnabled,
            apiKey: deepSeekAPIKey,
            curlTemplate: deepSeekConfiguration.curlTemplate
        ) {
        case .missingAPIKey:
            deepSeekStatusKey = "settings.deepSeek.status.missingAPIKey"
            deepSeekStatusIsError = true
        case .invalidTemplate:
            deepSeekStatusKey = "settings.deepSeek.status.invalidTemplate"
            deepSeekStatusIsError = true
        case .valid:
            DeepSeekAPIKeyStore.save(deepSeekAPIKey)
            DeepSeekBalanceConfiguration.save(deepSeekConfiguration)
            deepSeekStatusKey = "settings.deepSeek.status.saved"
            deepSeekStatusIsError = false
            Task {
                let succeeded = await store.refreshDeepSeekBalance()
                deepSeekStatusKey = succeeded
                    ? "settings.deepSeek.status.updated"
                    : "settings.deepSeek.status.queryFailed"
                deepSeekStatusIsError = !succeeded
            }
        }
    }

    private func addReminder() {
        let reminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: language.text("settings.reminder.defaultMessage"),
            scheduleType: .daily,
            actionType: ReminderActionType.none
        )
        reminders = ReminderListPolicy.prepending(reminder, to: reminders)
        reminderStatusKey = nil
    }

    private func deleteReminder(id: UUID) {
        reminders.removeAll { $0.id == id }
        reminderStatusKey = nil
    }

    private func saveDailyReminders() {
        var normalized = reminders
        for index in normalized.indices {
            normalized[index].message = normalized[index].normalizedMessage
            normalized[index].actionValue = normalized[index].normalizedActionValue
            normalized[index].workingDirectory = normalized[index].workingDirectory?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard normalized.allSatisfy({ !$0.normalizedMessage.isEmpty }) else {
            reminderStatusKey = "settings.reminder.status.empty"
            reminderStatusIsError = true
            return
        }
        guard normalized.allSatisfy({ $0.clickAction != nil }) else {
            reminderStatusKey = "settings.reminder.status.invalidAction"
            reminderStatusIsError = true
            return
        }
        guard normalized.allSatisfy(\.hasValidStoredShape) else {
            reminderStatusKey = "settings.reminder.status.invalidSchedule"
            reminderStatusIsError = true
            return
        }
        let enabled = normalized.filter(\.isEnabled)
        guard enabled.allSatisfy({ !$0.notificationSchedules().isEmpty }) else {
            reminderStatusKey = "settings.reminder.status.invalidSchedule"
            reminderStatusIsError = true
            return
        }

        reminders = normalized
        DailyReminderPreferences.saveAll(normalized)
        Task {
            let result = await notificationService.synchronizeReminders(
                normalized,
                title: language.text("notification.daily.title"),
                snoozeTenMinutesTitle: language.text("notification.snooze.10m"),
                snoozeOneHourTitle: language.text("notification.snooze.1h")
            )
            switch result {
            case .scheduled:
                reminderStatusKey = "settings.reminder.status.saved"
                reminderStatusIsError = false
            case .disabled:
                reminderStatusKey = "settings.reminder.status.disabled"
                reminderStatusIsError = false
            case .denied:
                reminderStatusKey = "settings.reminder.status.denied"
                reminderStatusIsError = true
            case .failed:
                reminderStatusKey = "settings.reminder.status.failed"
                reminderStatusIsError = true
            }
        }
    }
}

private struct SelectableAPIKeyTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var shouldSelectAll: Bool

    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField(string: text)
        textField.isBordered = true
        textField.isBezeled = true
        textField.focusRingType = .default
        textField.font = .systemFont(ofSize: NSFont.systemFontSize)
        textField.delegate = context.coordinator
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if shouldSelectAll {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
                nsView.currentEditor()?.selectAll(nil)
                shouldSelectAll = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
        }
    }
}

private struct DailyReminderEditor: View {
    let language: LanguageSettings
    @Binding var reminder: DailyReminderConfiguration
    let onDelete: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Toggle(language.text("settings.reminder.enabled"), isOn: $reminder.isEnabled)
                    Spacer()
                    if reminder.isCompleted() {
                        Label(
                            language.text("settings.reminder.status.completed"),
                            systemImage: "checkmark.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label(language.text("settings.reminder.delete"), systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .help(language.text("settings.reminder.delete"))
                }

                scheduleEditor

                VStack(alignment: .leading, spacing: 7) {
                    Label(language.text("settings.reminder.message"), systemImage: "text.alignleft")
                        .font(.subheadline.weight(.medium))
                    TextField(
                        language.text("settings.reminder.message"),
                        text: $reminder.message,
                        prompt: Text(language.text("settings.reminder.message.placeholder")),
                        axis: .vertical
                    )
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...3)
                    .disabled(!reminder.isEnabled)
                }

                actionEditor
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
    }

    @ViewBuilder
    private var scheduleEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(language.text("settings.reminder.schedule"), systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.medium))
            Picker(language.text("settings.reminder.schedule"), selection: scheduleType) {
                Text(language.text("settings.reminder.schedule.once")).tag(ReminderScheduleType.once)
                Text(language.text("settings.reminder.schedule.daily")).tag(ReminderScheduleType.daily)
                Text(language.text("settings.reminder.schedule.weekly")).tag(ReminderScheduleType.weekly)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .disabled(!reminder.isEnabled)

            switch reminder.scheduleType {
            case .once:
                DatePicker(
                    language.text("settings.reminder.schedule.date"),
                    selection: oneTimeDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .disabled(!reminder.isEnabled)
            case .daily:
                DatePicker(
                    language.text("settings.reminder.time"),
                    selection: reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .disabled(!reminder.isEnabled)
            case .weekly:
                DatePicker(
                    language.text("settings.reminder.time"),
                    selection: reminderTime,
                    displayedComponents: .hourAndMinute
                )
                .disabled(!reminder.isEnabled)
                HStack(spacing: 6) {
                    ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { weekday in
                        Toggle(weekdayTitle(weekday), isOn: weekdayBinding(weekday))
                            .toggleStyle(.button)
                            .controlSize(.small)
                    }
                    Spacer()
                    Button(language.text("settings.reminder.schedule.workdays")) {
                        reminder.weekdays = [2, 3, 4, 5, 6]
                    }
                    .controlSize(.small)
                }
                .disabled(!reminder.isEnabled)
            }
        }
    }

    @ViewBuilder
    private var actionEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(language.text("settings.reminder.action"), systemImage: "cursorarrow.click.2")
                .font(.subheadline.weight(.medium))
            Picker(language.text("settings.reminder.action"), selection: actionType) {
                Text(language.text("settings.reminder.action.none")).tag(ReminderActionType.none)
                Text(language.text("settings.reminder.action.url")).tag(ReminderActionType.url)
                Text(language.text("settings.reminder.action.path")).tag(ReminderActionType.openPath)
                Text(language.text("settings.reminder.action.shortcut")).tag(ReminderActionType.shortcut)
                Text(language.text("settings.reminder.action.python")).tag(ReminderActionType.python)
                Text(language.text("settings.reminder.action.deepSeek")).tag(ReminderActionType.deepSeekBalance)
            }
            .labelsHidden()
            .disabled(!reminder.isEnabled)

            switch reminder.actionType {
            case .none:
                Text(language.text("settings.reminder.action.none.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .url:
                actionTextField(
                    labelKey: "settings.reminder.action.url",
                    promptKey: "settings.reminder.url.placeholder",
                    icon: "link",
                    text: actionValue
                )
                Text(language.text("settings.reminder.url.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .openPath:
                pathPickerField(
                    labelKey: "settings.reminder.action.path",
                    icon: "folder",
                    text: actionValue,
                    chooseDirectory: false
                )
            case .shortcut:
                actionTextField(
                    labelKey: "settings.reminder.action.shortcut.name",
                    promptKey: "settings.reminder.action.shortcut.placeholder",
                    icon: "command",
                    text: actionValue
                )
            case .python:
                pathPickerField(
                    labelKey: "settings.reminder.action.python.script",
                    icon: "chevron.left.forwardslash.chevron.right",
                    text: actionValue,
                    chooseDirectory: false
                )
                pathPickerField(
                    labelKey: "settings.reminder.action.python.directory",
                    icon: "folder",
                    text: workingDirectory,
                    chooseDirectory: true
                )
                Text(language.text("settings.reminder.action.python.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .deepSeekBalance:
                Text(language.text("settings.reminder.action.deepSeek.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func actionTextField(
        labelKey: String,
        promptKey: String,
        icon: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(language.text(labelKey), systemImage: icon)
                .font(.caption.weight(.medium))
            TextField(
                language.text(labelKey),
                text: text,
                prompt: Text(language.text(promptKey))
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .disabled(!reminder.isEnabled)
        }
    }

    private func pathPickerField(
        labelKey: String,
        icon: String,
        text: Binding<String>,
        chooseDirectory: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(language.text(labelKey), systemImage: icon)
                .font(.caption.weight(.medium))
            HStack {
                TextField(language.text(labelKey), text: text)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                Button(language.text("settings.reminder.action.choose")) {
                    choosePath(for: text, directory: chooseDirectory)
                }
            }
            .disabled(!reminder.isEnabled)
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: reminder.hour,
                    minute: reminder.minute,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminder.hour = components.hour ?? reminder.hour
                reminder.minute = components.minute ?? reminder.minute
            }
        )
    }

    private var oneTimeDate: Binding<Date> {
        Binding(
            get: {
                let fallback = Date.now.addingTimeInterval(60 * 60)
                guard let scheduledDate = reminder.scheduledDate,
                      scheduledDate > .now else { return fallback }
                return scheduledDate
            },
            set: { reminder.scheduledDate = $0 }
        )
    }

    private var scheduleType: Binding<ReminderScheduleType> {
        Binding(
            get: { reminder.scheduleType },
            set: { newValue in
                reminder.scheduleType = newValue
                if newValue == .once,
                   reminder.scheduledDate == nil || reminder.scheduledDate! <= .now {
                    reminder.scheduledDate = .now.addingTimeInterval(60 * 60)
                }
                if newValue == .weekly, reminder.weekdays?.isEmpty != false {
                    reminder.weekdays = [2, 3, 4, 5, 6]
                }
            }
        )
    }

    private var actionType: Binding<ReminderActionType> {
        Binding(
            get: { reminder.actionType },
            set: { newValue in
                if newValue != reminder.actionType {
                    reminder.actionValue = nil
                    reminder.workingDirectory = nil
                }
                reminder.actionType = newValue
            }
        )
    }

    private var actionValue: Binding<String> {
        Binding(
            get: { reminder.normalizedActionValue ?? "" },
            set: { reminder.actionValue = $0.isEmpty ? nil : $0 }
        )
    }

    private var workingDirectory: Binding<String> {
        Binding(
            get: { reminder.workingDirectory ?? "" },
            set: { reminder.workingDirectory = $0.isEmpty ? nil : $0 }
        )
    }

    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(
            get: { reminder.weekdays?.contains(weekday) == true },
            set: { selected in
                var weekdays = reminder.weekdays ?? []
                if selected { weekdays.insert(weekday) }
                else { weekdays.remove(weekday) }
                reminder.weekdays = weekdays
            }
        )
    }

    private func weekdayTitle(_ weekday: Int) -> String {
        language.text("settings.reminder.weekday.\(weekday)")
    }

    private func choosePath(for binding: Binding<String>, directory: Bool) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = !directory
        panel.canChooseDirectories = directory
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        binding.wrappedValue = url.path
    }
}
