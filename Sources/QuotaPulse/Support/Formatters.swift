import Foundation

enum QuotaFormatters {
    static func reset(language: AppLanguage) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateFormat = language == .simplifiedChinese ? "M月d日 HH:mm" : "MMM d, HH:mm"
        return formatter
    }

    static func clock(language: AppLanguage, timeZone: TimeZone? = nil) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    static func weekday(language: AppLanguage, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE"
        return formatter
    }

    static func shortDate(language: AppLanguage) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateFormat = language == .simplifiedChinese ? "M/d" : "MMM d"
        return formatter
    }

    static func percent(_ remaining: Double?) -> String {
        guard let remaining else { return "--" }
        return "\(Int((remaining * 100).rounded()))%"
    }

    @MainActor static func relativeReset(from date: Date, language: LanguageSettings, now: Date = .now) -> String {
        let seconds = max(date.timeIntervalSince(now), 0)
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours >= 24 { return language.text("time.daysHours", hours / 24, hours % 24) }
        if hours > 0 { return language.text("time.hoursMinutes", hours, minutes) }
        return language.text("time.minutes", minutes)
    }
}

struct WorldClockTimes: Equatable {
    let localWeekday: String
    let local: String
    let unitedStatesWeekday: String
    let unitedStates: String
}

enum WorldClockDisplay {
    static let unitedStatesTimeZoneIdentifier = "America/Los_Angeles"

    static func times(
        at date: Date,
        localTimeZone: TimeZone = .autoupdatingCurrent,
        language: AppLanguage
    ) -> WorldClockTimes {
        let unitedStatesTimeZone = TimeZone(identifier: unitedStatesTimeZoneIdentifier)
            ?? TimeZone(secondsFromGMT: -8 * 60 * 60)!

        return WorldClockTimes(
            localWeekday: QuotaFormatters.weekday(language: language, timeZone: localTimeZone).string(from: date),
            local: QuotaFormatters.clock(language: language, timeZone: localTimeZone).string(from: date),
            unitedStatesWeekday: QuotaFormatters.weekday(language: language, timeZone: unitedStatesTimeZone).string(from: date),
            unitedStates: QuotaFormatters.clock(language: language, timeZone: unitedStatesTimeZone).string(from: date)
        )
    }
}
