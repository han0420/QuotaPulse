import Foundation
import Observation
import OSLog

@MainActor @Observable
final class QuotaStore {
    private struct QuotaReadingKey: Hashable {
        let providerId: String
        let period: String
    }

    private struct QuotaReading {
        let key: QuotaReadingKey
        let providerName: String
        let periodKey: String
        let remaining: Double
    }

    private(set) var providers: [ProviderUsage] = []
    private(set) var lastUpdated: Date?
    private(set) var errorMessageKey: String?
    private(set) var isRefreshing = false
    private(set) var activeProviderIds: Set<String> = []
    private(set) var weather: WeatherSnapshot?
    private(set) var locationStatusKey: String?
    private(set) var codexResetCredits: CodexResetCredits?
    private(set) var deepSeekBalance: DeepSeekBalance?
    private(set) var deepSeekBalanceError = false
    private(set) var weeklyQuotaPlanConfiguration = WeeklyQuotaPlanPreferences.load()

    private let client = OpenUsageClient()
    private let weatherClient = WeatherClient()
    private let locationClient = LocationClient()
    private let codexDirectClient = CodexDirectClient()
    private let claudeDirectClient = ClaudeDirectClient()
    private let notificationService: QuotaNotificationService
    private let language: LanguageSettings
    private let logger = Logger(subsystem: "com.cmsjcm.QuotaPulse.v2", category: "quota")
    private var activityTask: Task<Void, Never>?
    private var weatherTask: Task<Void, Never>?
    private var openUsageTask: Task<Void, Never>?
    private var codexTask: Task<Void, Never>?
    private var claudeTask: Task<Void, Never>?
    private var deepSeekTask: Task<Void, Never>?
    private var directCodexAvailable = false
    private var directClaudeAvailable = false
    private var previousQuotaRemaining: [QuotaReadingKey: Double]?

    init(notificationService: QuotaNotificationService, language: LanguageSettings) {
        self.notificationService = notificationService
        self.language = language
    }

    var isConsuming: Bool { !activeProviderIds.isEmpty }
    func isConsuming(_ provider: ProviderUsage) -> Bool {
        activeProviderIds.contains(provider.id)
    }

    var lowestRemaining: Double? {
        providers.flatMap { [$0.session?.remainingPercent, $0.weekly?.remainingPercent] }.compactMap { $0 }.min()
    }

    var health: QuotaHealth { QuotaHealth(remaining: lowestRemaining) }

    func updateWeeklyQuotaPlan(_ configuration: WeeklyQuotaPlanConfiguration) {
        WeeklyQuotaPlanPreferences.save(configuration)
        weeklyQuotaPlanConfiguration = configuration
    }

    func start() async {
        activityTask = Task { await monitorLocalActivity() }
        weatherTask = Task { await monitorWeather() }
        defer {
            activityTask?.cancel()
            weatherTask?.cancel()
            openUsageTask?.cancel()
            codexTask?.cancel()
        claudeTask?.cancel()
            deepSeekTask?.cancel()
        }
        await refresh()
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            await refresh()
        }
    }

    private func monitorWeather() async {
        while !Task.isCancelled {
            do {
                let location = try await locationClient.currentLocation()
                let locationName = await locationClient.displayName(for: location, language: .simplifiedChinese)
                let englishLocationName = await locationClient.displayName(for: location, language: .english)
                logger.info(
                    "Weather location resolved, accuracy \(Int(location.horizontalAccuracy), privacy: .public)m, age \(Int(abs(location.timestamp.timeIntervalSinceNow)), privacy: .public)s"
                )
                weather = try await weatherClient.fetch(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    locationName: locationName,
                    englishLocationName: englishLocationName
                )
                locationStatusKey = nil
            } catch LocationClient.LocationError.permissionDenied {
                weather = nil
                locationStatusKey = "location.permissionDenied"
            } catch LocationClient.LocationError.servicesDisabled {
                weather = nil
                locationStatusKey = "location.servicesDisabled"
            } catch {
                locationStatusKey = "location.weatherFailed"
            }
            try? await Task.sleep(for: .seconds(600))
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        launchOpenUsageRefresh()
        launchCodexRefresh()
        launchClaudeRefresh()
        launchDeepSeekRefresh()
    }

    private func launchOpenUsageRefresh() {
        guard openUsageTask == nil else { return }
        let client = client
        openUsageTask = Task { [weak self] in
            let result = try? await client.fetch()
            guard let self, !Task.isCancelled else { return }
            self.applyOpenUsage(result)
            self.openUsageTask = nil
        }
    }

    private func launchCodexRefresh() {
        guard codexTask == nil else { return }
        let client = codexDirectClient
        codexTask = Task { [weak self] in
            let result = try? await client.fetch()
            guard let self, !Task.isCancelled else { return }
            self.applyDirectCodex(result)
            self.codexTask = nil
        }
    }

    private func launchClaudeRefresh() {
        guard claudeTask == nil else { return }
        let client = claudeDirectClient
        claudeTask = Task { [weak self] in
            let result = try? await client.fetch()
            guard let self, !Task.isCancelled else { return }
            self.applyDirectClaude(result)
            self.claudeTask = nil
        }
    }

    private func launchDeepSeekRefresh() {
        guard deepSeekTask == nil else { return }
        let configuration = DeepSeekBalanceConfiguration.load()
        guard configuration.isEnabled else {
            deepSeekBalance = nil
            deepSeekBalanceError = false
            return
        }
        deepSeekTask = Task { [weak self] in
            guard let self else { return }
            _ = await self.refreshDeepSeekBalance(configuration: configuration)
            guard !Task.isCancelled else { return }
            self.deepSeekTask = nil
        }
    }

    func refreshDeepSeekBalance() async -> Bool {
        await refreshDeepSeekBalance(configuration: DeepSeekBalanceConfiguration.load())
    }

    private func refreshDeepSeekBalance(configuration: DeepSeekBalanceConfiguration) async -> Bool {
        guard configuration.isEnabled else {
            deepSeekBalance = nil
            deepSeekBalanceError = false
            return true
        }
        let result = await DeepSeekBalanceClient.fetch(configuration: configuration)
        guard !Task.isCancelled else { return false }
        deepSeekBalance = result
        deepSeekBalanceError = result == nil
        return result != nil
    }

    private func applyOpenUsage(_ result: [ProviderUsage]?) {
        guard let result else {
            logger.info("OpenUsage refresh failed")
            setFailureMessageIfNeeded()
            return
        }

        var fresh = providers
        for provider in result {
            let providerId = provider.providerId.lowercased()
            if providerId == "codex", directCodexAvailable { continue }
            if providerId == "claude", directClaudeAvailable { continue }
            replace(provider, in: &fresh)
        }
        commit(fresh)
        logger.info("OpenUsage refresh succeeded")
    }

    private func applyDirectCodex(_ result: CodexDirectSnapshot?) {
        guard let result else {
            logger.info("Codex direct refresh failed")
            setFailureMessageIfNeeded()
            return
        }

        directCodexAvailable = true
        var fresh = providers
        replace(result.provider, in: &fresh)
        if let resetCredits = result.resetCredits { codexResetCredits = resetCredits }
        commit(fresh)
        logger.info("Codex direct refresh succeeded")
    }

    private func applyDirectClaude(_ result: ProviderUsage?) {
        guard let result else {
            logger.info("Claude direct refresh failed")
            setFailureMessageIfNeeded()
            return
        }

        directClaudeAvailable = true
        var fresh = providers
        replace(result, in: &fresh)
        commit(fresh)
        logger.info("Claude direct refresh succeeded")
    }

    private func replace(_ provider: ProviderUsage, in providers: inout [ProviderUsage]) {
        providers.removeAll { $0.providerId.caseInsensitiveCompare(provider.providerId) == .orderedSame }
        providers.append(provider)
    }

    private func commit(_ fresh: [ProviderUsage]) {
        let sorted = fresh.sorted {
            if $0.providerId.lowercased() == "codex" { return true }
            if $1.providerId.lowercased() == "codex" { return false }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        notifyForCrossedQuotaThresholds(in: sorted)
        providers = sorted
        lastUpdated = .now
        errorMessageKey = nil
    }

    private func notifyForCrossedQuotaThresholds(in providers: [ProviderUsage]) {
        let readings = quotaReadings(in: providers)
        defer { previousQuotaRemaining = Dictionary(uniqueKeysWithValues: readings.map { ($0.key, $0.remaining) }) }
        guard let previousQuotaRemaining else { return }

        for reading in readings {
            guard let previous = previousQuotaRemaining[reading.key],
                let threshold = QuotaNotificationPolicy.crossedThreshold(
                    previous: previous,
                    current: reading.remaining,
                    configuration: QuotaNotificationPreferences.load()
                  ) else { continue }

            let thresholdPercent = Int((threshold * 100).rounded())
            let currentPercent = Int((reading.remaining * 100).rounded())
            let title = language.text("notification.quota.title", thresholdPercent)
            let body = language.text(
                "notification.quota.body",
                reading.providerName,
                language.text(reading.periodKey),
                currentPercent
            )
            Task { await notificationService.send(title: title, body: body) }
        }
    }

    private func quotaReadings(in providers: [ProviderUsage]) -> [QuotaReading] {
        providers.flatMap { provider in
            var result: [QuotaReading] = []
            if let remaining = provider.session?.remainingPercent {
                result.append(QuotaReading(
                    key: QuotaReadingKey(providerId: provider.providerId.lowercased(), period: "session"),
                    providerName: provider.displayName,
                    periodKey: "quota.session",
                    remaining: remaining
                ))
            }
            if let remaining = provider.weekly?.remainingPercent {
                result.append(QuotaReading(
                    key: QuotaReadingKey(providerId: provider.providerId.lowercased(), period: "weekly"),
                    providerName: provider.displayName,
                    periodKey: "quota.weekly",
                    remaining: remaining
                ))
            }
            return result
        }
    }

    private func setFailureMessageIfNeeded() {
        guard providers.isEmpty else { return }
        errorMessageKey = "error.quotaUnavailable"
    }

    private func monitorLocalActivity() async {
        while !Task.isCancelled {
            let detected = detectLocalActivity()
            if detected != activeProviderIds {
                logger.info("Local activity changed: \(detected.sorted().joined(separator: ","), privacy: .public)")
            }
            activeProviderIds = detected
            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func detectLocalActivity(now: Date = .now) -> Set<String> {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var active: Set<String> = []

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy/MM/dd"
        let codexDirectory = home
            .appendingPathComponent(".codex/sessions", isDirectory: true)
            .appendingPathComponent(dayFormatter.string(from: now), isDirectory: true)
        if hasRecentlyModifiedJSONL(in: codexDirectory, now: now) { active.insert("codex") }

        let claudeDirectory = home.appendingPathComponent(".claude/projects", isDirectory: true)
        if hasRecentlyModifiedJSONL(in: claudeDirectory, now: now) { active.insert("claude") }
        return active
    }

    private func hasRecentlyModifiedJSONL(in directory: URL, now: Date) -> Bool {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return false }

        for case let fileURL as URL in enumerator where fileURL.pathExtension == "jsonl" {
            guard let values = try? fileURL.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true,
                  let modified = values.contentModificationDate else { continue }
            if ActivityDetectionPolicy.isActive(modifiedAt: modified, now: now) { return true }
        }
        return false
    }

}

enum ActivityDetectionPolicy {
    static let recentWriteWindow: TimeInterval = 4

    static func isActive(modifiedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(modifiedAt)
        return age >= -1 && age <= recentWriteWindow
    }
}
