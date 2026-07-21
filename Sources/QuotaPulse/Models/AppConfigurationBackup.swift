import Foundation

struct AppConfigurationBackup: Codable, Equatable {
    static let currentVersion = 1

    let version: Int
    let language: AppLanguage
    let quotaNotification: QuotaNotificationConfiguration
    let deepSeek: DeepSeekBalanceConfiguration
    let dailyReminders: [DailyReminderConfiguration]
}

enum AppConfigurationBackupError: Error, Equatable {
    case unsupportedVersion(Int)
    case invalidQuotaNotification
    case invalidDailyReminder
}

enum AppConfigurationBackupService {
    private static let languageKey = "QuotaPulse.appLanguage"

    static func exportData(from defaults: UserDefaults = .standard) throws -> Data {
        let language = defaults.string(forKey: languageKey)
            .flatMap(AppLanguage.init(rawValue:)) ?? .systemDefault
        var deepSeek = DeepSeekBalanceConfiguration.load(from: defaults)
        if let apiKey = DeepSeekAPIKeyStore.load(from: defaults) {
            deepSeek.curlTemplate = deepSeek.curlTemplate.replacingOccurrences(
                of: apiKey,
                with: "<API_KEY>"
            )
        }
        let backup = AppConfigurationBackup(
            version: AppConfigurationBackup.currentVersion,
            language: language,
            quotaNotification: QuotaNotificationPreferences.load(from: defaults),
            deepSeek: deepSeek,
            dailyReminders: DailyReminderPreferences.loadAll(from: defaults)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(backup)
    }

    @discardableResult
    static func importData(
        _ data: Data,
        to defaults: UserDefaults = .standard
    ) throws -> AppConfigurationBackup {
        let backup = try JSONDecoder().decode(AppConfigurationBackup.self, from: data)
        guard backup.version == AppConfigurationBackup.currentVersion else {
            throw AppConfigurationBackupError.unsupportedVersion(backup.version)
        }
        guard backup.quotaNotification.isValid else {
            throw AppConfigurationBackupError.invalidQuotaNotification
        }
        guard backup.dailyReminders.allSatisfy(isStructurallyValid) else {
            throw AppConfigurationBackupError.invalidDailyReminder
        }

        defaults.set(backup.language.rawValue, forKey: languageKey)
        QuotaNotificationPreferences.save(backup.quotaNotification, to: defaults)
        DeepSeekBalanceConfiguration.save(backup.deepSeek, to: defaults)
        DailyReminderPreferences.saveAll(backup.dailyReminders, to: defaults)
        return backup
    }

    private static func isStructurallyValid(_ reminder: DailyReminderConfiguration) -> Bool {
        guard reminder.isEnabled else { return true }
        guard !reminder.normalizedMessage.isEmpty,
              reminder.clickAction != nil,
              reminder.triggerDateComponents != nil else { return false }
        switch reminder.effectiveScheduleType {
        case .once:
            return reminder.scheduledDate != nil
        case .daily:
            return true
        case .weekly:
            guard let weekdays = reminder.weekdays else { return false }
            return !weekdays.isEmpty && weekdays.allSatisfy { (1...7).contains($0) }
        }
    }
}
