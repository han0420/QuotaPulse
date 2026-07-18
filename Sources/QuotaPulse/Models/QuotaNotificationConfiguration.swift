import Foundation

struct QuotaNotificationConfiguration: Codable, Equatable {
    enum Mode: String, Codable, CaseIterable {
        case singleStage
        case twoStage
    }

    var mode: Mode
    var breakpointPercent: Int
    var firstIntervalPercent: Int
    var secondIntervalPercent: Int

    static func singleStage(intervalPercent: Int) -> Self {
        Self(
            mode: .singleStage,
            breakpointPercent: 50,
            firstIntervalPercent: intervalPercent,
            secondIntervalPercent: intervalPercent
        )
    }

    static func twoStage(
        breakpointPercent: Int,
        firstIntervalPercent: Int,
        secondIntervalPercent: Int
    ) -> Self {
        Self(
            mode: .twoStage,
            breakpointPercent: breakpointPercent,
            firstIntervalPercent: firstIntervalPercent,
            secondIntervalPercent: secondIntervalPercent
        )
    }

    var isValid: Bool {
        guard (1...99).contains(firstIntervalPercent) else { return false }
        switch mode {
        case .singleStage:
            return true
        case .twoStage:
            return (1...99).contains(breakpointPercent)
                && (1...99).contains(secondIntervalPercent)
        }
    }

    var remainingThresholdPercents: [Int] {
        guard isValid else { return [] }

        var consumedThresholds = stride(
            from: firstIntervalPercent,
            through: mode == .singleStage ? 99 : breakpointPercent,
            by: firstIntervalPercent
        ).map { $0 }

        if mode == .twoStage {
            if consumedThresholds.last != breakpointPercent {
                consumedThresholds.append(breakpointPercent)
            }
            consumedThresholds += stride(
                from: breakpointPercent + secondIntervalPercent,
                through: 99,
                by: secondIntervalPercent
            ).map { $0 }
        }

        return consumedThresholds.map { 100 - $0 }
    }
}

enum QuotaNotificationPreferences {
    private static let storageKey = "QuotaPulse.quotaNotification.configuration"
    static let defaultConfiguration = QuotaNotificationConfiguration.singleStage(intervalPercent: 10)

    static func load(from defaults: UserDefaults = .standard) -> QuotaNotificationConfiguration {
        guard let data = defaults.data(forKey: storageKey),
              let configuration = try? JSONDecoder().decode(QuotaNotificationConfiguration.self, from: data),
              configuration.isValid else { return defaultConfiguration }
        return configuration
    }

    static func save(
        _ configuration: QuotaNotificationConfiguration,
        to defaults: UserDefaults = .standard
    ) {
        guard configuration.isValid,
              let data = try? JSONEncoder().encode(configuration) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
