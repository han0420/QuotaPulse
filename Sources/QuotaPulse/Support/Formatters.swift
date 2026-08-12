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

    @MainActor static func resetCountdown(
        from date: Date,
        language: LanguageSettings,
        now: Date = .now
    ) -> String? {
        guard date > now else { return nil }
        return language.text(
            "time.remaining",
            relativeReset(from: date, language: language, now: now)
        )
    }

    @MainActor static func compactResetCountdown(
        from date: Date,
        language: LanguageSettings,
        now: Date = .now
    ) -> String? {
        guard date > now else { return nil }
        let seconds = Int(date.timeIntervalSince(now))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours >= 24 {
            return language.text("time.compact.daysHoursRemaining", hours / 24, hours % 24)
        }
        if hours > 0 {
            return language.text("time.compact.hoursMinutesRemaining", hours, minutes)
        }
        return language.text("time.compact.minutesRemaining", minutes)
    }
}

enum WorldClockDateRelation: Equatable {
    case yesterday
    case today
    case tomorrow

    var localizationKey: String {
        switch self {
        case .yesterday: "clock.date.yesterday"
        case .today: "clock.date.today"
        case .tomorrow: "clock.date.tomorrow"
        }
    }
}

struct WorldClockTimes: Equatable {
    let localWeekday: String
    let local: String
    let localDateRelation: WorldClockDateRelation?
    let unitedStatesWeekday: String
    let unitedStates: String
    let unitedStatesDateRelation: WorldClockDateRelation?
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
        let dateRelations = dateRelations(
            at: date,
            localTimeZone: localTimeZone,
            unitedStatesTimeZone: unitedStatesTimeZone
        )

        return WorldClockTimes(
            localWeekday: QuotaFormatters.weekday(language: language, timeZone: localTimeZone).string(from: date),
            local: QuotaFormatters.clock(language: language, timeZone: localTimeZone).string(from: date),
            localDateRelation: dateRelations.local,
            unitedStatesWeekday: QuotaFormatters.weekday(language: language, timeZone: unitedStatesTimeZone).string(from: date),
            unitedStates: QuotaFormatters.clock(language: language, timeZone: unitedStatesTimeZone).string(from: date),
            unitedStatesDateRelation: dateRelations.unitedStates
        )
    }

    private static func dateRelations(
        at date: Date,
        localTimeZone: TimeZone,
        unitedStatesTimeZone: TimeZone
    ) -> (local: WorldClockDateRelation?, unitedStates: WorldClockDateRelation?) {
        guard let localDate = comparisonDate(at: date, in: localTimeZone),
              let unitedStatesDate = comparisonDate(at: date, in: unitedStatesTimeZone),
              localDate != unitedStatesDate else {
            return (nil, nil)
        }

        return (
            .today,
            unitedStatesDate < localDate ? .yesterday : .tomorrow
        )
    }

    private static func comparisonDate(at date: Date, in timeZone: TimeZone) -> Date? {
        var sourceCalendar = Calendar(identifier: .gregorian)
        sourceCalendar.timeZone = timeZone
        let components = sourceCalendar.dateComponents([.year, .month, .day], from: date)

        var comparisonCalendar = Calendar(identifier: .gregorian)
        comparisonCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return comparisonCalendar.date(from: components)
    }
}
