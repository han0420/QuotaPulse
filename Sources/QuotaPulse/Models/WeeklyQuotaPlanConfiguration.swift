import Foundation

struct WeeklyQuotaPlanConfiguration: Codable, Equatable, Sendable {
    var excludesWeekends: Bool

    init(excludesWeekends: Bool = false) {
        self.excludesWeekends = excludesWeekends
    }
}

enum WeeklyQuotaPlanPreferences {
    private static let storageKey = "QuotaPulse.v2.weeklyQuotaPlan.configuration"

    static func load(from defaults: UserDefaults = .standard) -> WeeklyQuotaPlanConfiguration {
        guard let data = defaults.data(forKey: storageKey),
              let configuration = try? JSONDecoder().decode(
                WeeklyQuotaPlanConfiguration.self,
                from: data
              ) else { return WeeklyQuotaPlanConfiguration() }
        return configuration
    }

    static func save(
        _ configuration: WeeklyQuotaPlanConfiguration,
        to defaults: UserDefaults = .standard
    ) {
        guard let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
