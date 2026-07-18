import Foundation

enum ReminderScheduleType: String, Codable, CaseIterable, Sendable {
    case once
    case daily
    case weekly
}

enum ReminderActionType: String, Codable, CaseIterable, Sendable {
    case none
    case url
    case openPath
    case shortcut
    case python
}

enum ReminderClickAction: Equatable, Sendable {
    case none
    case openURL(URL)
    case openPath(String)
    case shortcut(String)
    case python(scriptPath: String, workingDirectory: String)
}

struct ReminderActionPayload: Equatable, Sendable {
    static let typeKey = "QuotaDot.action.type"
    static let valueKey = "QuotaDot.action.value"
    static let workingDirectoryKey = "QuotaDot.action.workingDirectory"

    let type: ReminderActionType
    let value: String?
    let workingDirectory: String?

    init(action: ReminderClickAction) {
        switch action {
        case .none:
            self.init(type: .none, value: nil, workingDirectory: nil)
        case .openURL(let url):
            self.init(type: .url, value: url.absoluteString, workingDirectory: nil)
        case .openPath(let path):
            self.init(type: .openPath, value: path, workingDirectory: nil)
        case .shortcut(let name):
            self.init(type: .shortcut, value: name, workingDirectory: nil)
        case .python(let scriptPath, let workingDirectory):
            self.init(type: .python, value: scriptPath, workingDirectory: workingDirectory)
        }
    }

    init(type: ReminderActionType, value: String?, workingDirectory: String?) {
        self.type = type
        self.value = value
        self.workingDirectory = workingDirectory
    }

    init?(userInfo: [AnyHashable: Any]) {
        guard let rawType = userInfo[Self.typeKey] as? String,
              let type = ReminderActionType(rawValue: rawType) else { return nil }
        self.init(
            type: type,
            value: userInfo[Self.valueKey] as? String,
            workingDirectory: userInfo[Self.workingDirectoryKey] as? String
        )
    }

    var userInfo: [AnyHashable: Any] {
        var result: [AnyHashable: Any] = [Self.typeKey: type.rawValue]
        if let value { result[Self.valueKey] = value }
        if let workingDirectory { result[Self.workingDirectoryKey] = workingDirectory }
        return result
    }

    var clickAction: ReminderClickAction? {
        switch type {
        case .none:
            return ReminderClickAction.none
        case .url:
            guard let url = DailyReminderConfiguration.webURL(from: value) else { return nil }
            return .openURL(url)
        case .openPath:
            guard let value, value.hasPrefix("/") else { return nil }
            return .openPath(value)
        case .shortcut:
            guard let value, !value.isEmpty else { return nil }
            return .shortcut(value)
        case .python:
            guard let value,
                  value.hasPrefix("/"),
                  URL(fileURLWithPath: value).pathExtension.lowercased() == "py",
                  let workingDirectory,
                  workingDirectory.hasPrefix("/") else { return nil }
            return .python(scriptPath: value, workingDirectory: workingDirectory)
        }
    }
}

struct ReminderNotificationSchedule: Equatable, Sendable {
    let identifier: String
    let dateComponents: DateComponents
    let repeats: Bool
}

struct DailyReminderConfiguration: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var isEnabled: Bool
    var hour: Int
    var minute: Int
    var message: String
    var urlString: String?
    var scheduleType: ReminderScheduleType?
    var scheduledDate: Date?
    var weekdays: Set<Int>?
    var actionType: ReminderActionType?
    var actionValue: String?
    var workingDirectory: String?

    init(
        id: UUID = UUID(),
        isEnabled: Bool,
        hour: Int,
        minute: Int,
        message: String,
        urlString: String? = nil,
        scheduleType: ReminderScheduleType? = nil,
        scheduledDate: Date? = nil,
        weekdays: Set<Int>? = nil,
        actionType: ReminderActionType? = nil,
        actionValue: String? = nil,
        workingDirectory: String? = nil
    ) {
        self.id = id
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
        self.message = message
        self.urlString = urlString
        self.scheduleType = scheduleType
        self.scheduledDate = scheduledDate
        self.weekdays = weekdays
        self.actionType = actionType
        self.actionValue = actionValue
        self.workingDirectory = workingDirectory
    }

    var effectiveScheduleType: ReminderScheduleType { scheduleType ?? .daily }

    var effectiveActionType: ReminderActionType {
        if let actionType { return actionType }
        return normalizedURLString == nil ? .none : .url
    }

    var effectiveActionValue: String? {
        let normalizedAction = actionValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let normalizedAction, !normalizedAction.isEmpty { return normalizedAction }
        return effectiveActionType == .url ? normalizedURLString : nil
    }

    var normalizedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var triggerDateComponents: DateComponents? {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return DateComponents(hour: hour, minute: minute)
    }

    var normalizedURLString: String? {
        let normalized = urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    var destinationURL: URL? {
        Self.webURL(from: effectiveActionValue)
    }

    static func webURL(from rawValue: String?) -> URL? {
        let normalized = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !normalized.isEmpty,
              let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else { return nil }
        return url
    }

    var clickAction: ReminderClickAction? {
        switch effectiveActionType {
        case .none:
            return ReminderClickAction.none
        case .url:
            guard let destinationURL else { return nil }
            return .openURL(destinationURL)
        case .openPath:
            guard let path = effectiveActionValue, path.hasPrefix("/") else { return nil }
            return .openPath(path)
        case .shortcut:
            guard let name = effectiveActionValue, !name.isEmpty else { return nil }
            return .shortcut(name)
        case .python:
            guard let scriptPath = effectiveActionValue,
                  scriptPath.hasPrefix("/"),
                  URL(fileURLWithPath: scriptPath).pathExtension.lowercased() == "py",
                  let workingDirectory = workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
                  workingDirectory.hasPrefix("/") else { return nil }
            return .python(scriptPath: scriptPath, workingDirectory: workingDirectory)
        }
    }

    var hasValidDestination: Bool { clickAction != nil }

    var isValid: Bool { isValid(at: .now) }

    func isValid(at now: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled else { return true }
        return !normalizedMessage.isEmpty
            && clickAction != nil
            && !notificationSchedules(now: now, calendar: calendar).isEmpty
    }

    func notificationSchedules(
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ReminderNotificationSchedule] {
        guard let time = triggerDateComponents else { return [] }
        switch effectiveScheduleType {
        case .once:
            guard let scheduledDate, scheduledDate > now else { return [] }
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: scheduledDate
            )
            return [ReminderNotificationSchedule(
                identifier: "\(notificationIdentifier).once",
                dateComponents: components,
                repeats: false
            )]
        case .daily:
            return [ReminderNotificationSchedule(
                identifier: "\(notificationIdentifier).daily",
                dateComponents: time,
                repeats: true
            )]
        case .weekly:
            return (weekdays ?? [])
                .filter { (1...7).contains($0) }
                .sorted()
                .map { weekday in
                    ReminderNotificationSchedule(
                        identifier: "\(notificationIdentifier).weekday.\(weekday)",
                        dateComponents: DateComponents(
                            hour: hour,
                            minute: minute,
                            weekday: weekday
                        ),
                        repeats: true
                    )
                }
        }
    }

    var notificationIdentifier: String {
        "com.cmsjcm.QuotaDot.daily-reminder.\(id.uuidString.lowercased())"
    }
}

enum DailyReminderPreferences {
    private static let remindersKey = "QuotaDot.dailyReminders.v1"
    private static let enabledKey = "QuotaDot.dailyReminder.enabled"
    private static let hourKey = "QuotaDot.dailyReminder.hour"
    private static let minuteKey = "QuotaDot.dailyReminder.minute"
    private static let messageKey = "QuotaDot.dailyReminder.message"

    static func loadAll(from defaults: UserDefaults = .standard) -> [DailyReminderConfiguration] {
        if let data = defaults.data(forKey: remindersKey),
           let reminders = try? JSONDecoder().decode([DailyReminderConfiguration].self, from: data) {
            return reminders
        }

        guard defaults.object(forKey: enabledKey) != nil || defaults.object(forKey: messageKey) != nil else {
            return []
        }
        let migrated = DailyReminderConfiguration(
            isEnabled: defaults.bool(forKey: enabledKey),
            hour: defaults.object(forKey: hourKey) as? Int ?? 9,
            minute: defaults.object(forKey: minuteKey) as? Int ?? 0,
            message: defaults.string(forKey: messageKey) ?? ""
        )
        saveAll([migrated], to: defaults)
        return [migrated]
    }

    static func saveAll(
        _ configurations: [DailyReminderConfiguration],
        to defaults: UserDefaults = .standard
    ) {
        guard let data = try? JSONEncoder().encode(configurations) else { return }
        defaults.set(data, forKey: remindersKey)
    }
}
