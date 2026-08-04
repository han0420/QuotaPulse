import Foundation
import CoreLocation
import XCTest
@testable import QuotaPulse

final class QuotaModelsTests: XCTestCase {
    func testSingleInstancePolicyKeepsOnlyLaunchWithoutAnotherProcess() {
        XCTAssertFalse(
            SingleInstancePolicy.shouldTerminateCurrentProcess(
                currentProcessIdentifier: 42,
                runningProcessIdentifiers: [42]
            )
        )
        XCTAssertFalse(
            SingleInstancePolicy.shouldTerminateCurrentProcess(
                currentProcessIdentifier: 42,
                runningProcessIdentifiers: [42, 42]
            )
        )
        XCTAssertTrue(
            SingleInstancePolicy.shouldTerminateCurrentProcess(
                currentProcessIdentifier: 42,
                runningProcessIdentifiers: [42, 77]
            )
        )
    }

    func testFreshStartClearsExistingPreferencesOnceAndPreservesV2PreferencesAfterward() throws {
        let suiteName = "QuotaPulseTests.fresh-start-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("retired", forKey: "retired.preference")
        defaults.set("secret", forKey: "retired.secret")

        XCTAssertTrue(FreshStartPolicy.prepare(defaults: defaults))
        XCTAssertNil(defaults.object(forKey: "retired.preference"))
        XCTAssertNil(defaults.object(forKey: "retired.secret"))
        XCTAssertTrue(defaults.bool(forKey: FreshStartPolicy.completionKey))

        defaults.set("en", forKey: "QuotaPulse.v2.appLanguage")
        XCTAssertFalse(FreshStartPolicy.prepare(defaults: defaults))
        XCTAssertEqual(defaults.string(forKey: "QuotaPulse.v2.appLanguage"), "en")
    }

    func testConfigurationBackupUsesOnlyVersionTwo() {
        XCTAssertEqual(AppConfigurationBackup.currentVersion, 2)
    }

    func testConfigurationBackupRoundTripsOnlyNonSensitivePreferences() throws {
        let sourceName = "ConfigurationBackupSource-\(UUID().uuidString)"
        let destinationName = "ConfigurationBackupDestination-\(UUID().uuidString)"
        let source = try XCTUnwrap(UserDefaults(suiteName: sourceName))
        let destination = try XCTUnwrap(UserDefaults(suiteName: destinationName))
        defer {
            source.removePersistentDomain(forName: sourceName)
            destination.removePersistentDomain(forName: destinationName)
        }

        source.set(AppLanguage.simplifiedChinese.rawValue, forKey: "QuotaPulse.v2.appLanguage")
        let quota = QuotaNotificationConfiguration.twoStage(
            breakpointPercent: 60,
            firstIntervalPercent: 10,
            secondIntervalPercent: 5
        )
        QuotaNotificationPreferences.save(quota, to: source)
        let deepSeek = DeepSeekBalanceConfiguration(
            isEnabled: true,
            curlTemplate: "curl https://api.deepseek.com/user/balance -H 'Authorization: Bearer <API_KEY>' -H 'Debug: secret-api-key'"
        )
        DeepSeekBalanceConfiguration.save(deepSeek, to: source)
        let reminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 8,
            minute: 30,
            message: "Daily review"
        )
        DailyReminderPreferences.saveAll([reminder], to: source)
        DeepSeekAPIKeyStore.save("secret-api-key", to: source)
        source.set("secret-local-token", forKey: "QuotaPulse.v2.localNotificationHTTP.token")

        let data = try AppConfigurationBackupService.exportData(from: source)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(json.contains("secret-api-key"))
        XCTAssertFalse(json.contains("secret-local-token"))

        let imported = try AppConfigurationBackupService.importData(data, to: destination)

        XCTAssertEqual(imported.language, .simplifiedChinese)
        XCTAssertEqual(destination.string(forKey: "QuotaPulse.v2.appLanguage"), AppLanguage.simplifiedChinese.rawValue)
        XCTAssertEqual(QuotaNotificationPreferences.load(from: destination), quota)
        XCTAssertEqual(
            DeepSeekBalanceConfiguration.load(from: destination).curlTemplate,
            "curl https://api.deepseek.com/user/balance -H 'Authorization: Bearer <API_KEY>' -H 'Debug: <API_KEY>'"
        )
        XCTAssertEqual(DailyReminderPreferences.loadAll(from: destination), [reminder])
        XCTAssertNil(DeepSeekAPIKeyStore.load(from: destination))
        XCTAssertNil(destination.string(forKey: "QuotaPulse.v2.localNotificationHTTP.token"))
    }

    func testConfigurationBackupRejectsUnsupportedVersionWithoutChangingPreferences() throws {
        let suiteName = "ConfigurationBackupInvalid-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AppLanguage.english.rawValue, forKey: "QuotaPulse.v2.appLanguage")

        let data = #"{"version":99,"language":"zh-Hans","quotaNotification":{"mode":"singleStage","breakpointPercent":50,"firstIntervalPercent":10,"secondIntervalPercent":10},"deepSeek":{"isEnabled":false,"curlTemplate":"curl safe"},"dailyReminders":[]}"#.data(using: .utf8)!

        XCTAssertThrowsError(try AppConfigurationBackupService.importData(data, to: defaults))
        XCTAssertEqual(defaults.string(forKey: "QuotaPulse.v2.appLanguage"), AppLanguage.english.rawValue)
        XCTAssertThrowsError(
            try AppConfigurationBackupService.importData(Data("not-json".utf8), to: defaults)
        )
        XCTAssertEqual(defaults.string(forKey: "QuotaPulse.v2.appLanguage"), AppLanguage.english.rawValue)
    }

    func testConfigurationBackupRejectsInvalidQuotaConfigurationAtomically() throws {
        let suiteName = "ConfigurationBackupInvalidQuota-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AppLanguage.english.rawValue, forKey: "QuotaPulse.v2.appLanguage")

        let data = #"{"version":2,"language":"zh-Hans","quotaNotification":{"mode":"singleStage","breakpointPercent":50,"firstIntervalPercent":0,"secondIntervalPercent":0},"deepSeek":{"isEnabled":false,"curlTemplate":"curl safe"},"dailyReminders":[]}"#.data(using: .utf8)!

        XCTAssertThrowsError(try AppConfigurationBackupService.importData(data, to: defaults))
        XCTAssertEqual(defaults.string(forKey: "QuotaPulse.v2.appLanguage"), AppLanguage.english.rawValue)
    }

    func testConfigurationBackupRejectsStructurallyInvalidReminderAtomically() throws {
        let suiteName = "ConfigurationBackupInvalidReminder-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AppLanguage.english.rawValue, forKey: "QuotaPulse.v2.appLanguage")

        let reminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 99,
            minute: 0,
            message: "Invalid time",
            scheduleType: .daily,
            actionType: ReminderActionType.none
        )
        let backup = AppConfigurationBackup(
            version: AppConfigurationBackup.currentVersion,
            language: .simplifiedChinese,
            quotaNotification: .singleStage(intervalPercent: 10),
            deepSeek: DeepSeekBalanceConfiguration(),
            dailyReminders: [reminder]
        )
        let data = try JSONEncoder().encode(backup)

        XCTAssertThrowsError(try AppConfigurationBackupService.importData(data, to: defaults))
        XCTAssertEqual(defaults.string(forKey: "QuotaPulse.v2.appLanguage"), AppLanguage.english.rawValue)
    }

    func testLocalNotificationHTTPAPIParsesAuthorizedNotificationRequest() throws {
        let result = LocalNotificationHTTPRequest.parse(
            raw: "POST /v1/notifications HTTP/1.1\r\nHost: 127.0.0.1\r\nAuthorization: Bearer secret\r\nContent-Length: 38\r\n\r\n{\"title\":\"Build\",\"body\":\"Done\"}",
            token: "secret"
        )
        let request = try XCTUnwrap(try? result.get())

        XCTAssertEqual(request.title, "Build")
        XCTAssertEqual(request.body, "Done")
    }

    func testLocalNotificationHTTPAPIRejectsInvalidRequests() {
        XCTAssertEqual(
            LocalNotificationHTTPRequest.parse(
                raw: "POST /v1/notifications HTTP/1.1\r\nAuthorization: Bearer wrong\r\n\r\n{}",
                token: "secret"
            ),
            .failure(.unauthorized)
        )
        XCTAssertEqual(
            LocalNotificationHTTPRequest.parse(
                raw: "GET /v1/notifications HTTP/1.1\r\nAuthorization: Bearer secret\r\n\r\n",
                token: "secret"
            ),
            .failure(.methodNotAllowed)
        )
    }


    func testNotificationAuthorizationRequestsOnlyWhenUndetermined() {
        XCTAssertTrue(NotificationAuthorizationState.notDetermined.shouldRequestAuthorization)
        XCTAssertFalse(NotificationAuthorizationState.authorized.shouldRequestAuthorization)
        XCTAssertFalse(NotificationAuthorizationState.denied.shouldRequestAuthorization)
    }

    func testReminderSynchronizationRemovesOnlyCurrentV2ReminderIdentifiers() {
        let identifiers = [
            "com.cmsjcm.QuotaPulse.v2.daily-reminder.current.daily",
            "com.cmsjcm.QuotaPulse.daily-reminder.retired.daily",
            "unrelated.notification"
        ]

        XCTAssertEqual(
            ReminderNotificationIdentifierPolicy.identifiersToRemove(from: identifiers),
            [identifiers[0]]
        )
    }

    func testDeepSeekBalanceDecodesOfficialResponse() throws {
        let data = #"{"is_available":true,"balance_infos":[{"currency":"CNY","total_balance":"110.00","granted_balance":"10.00","topped_up_balance":"100.00"}]}"#.data(using: .utf8)!
        let balance = try DeepSeekBalanceParser.parse(data: data)
        XCTAssertTrue(balance.isAvailable)
        XCTAssertEqual(balance.displayLines, ["CNY 110.00"])
    }

    func testDeepSeekConfigurationDefaultsDisabledAndPersistsTemplate() {
        let suiteName = "DeepSeekBalanceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let configuration = DeepSeekBalanceConfiguration.load(from: defaults)
        XCTAssertFalse(configuration.isEnabled)
        XCTAssertEqual(configuration.curlTemplate, DeepSeekBalanceConfiguration.defaultCurlTemplate)
        var changed = configuration
        changed.isEnabled = true
        DeepSeekBalanceConfiguration.save(changed, to: defaults)
        XCTAssertEqual(DeepSeekBalanceConfiguration.load(from: defaults), changed)
    }

    func testDeepSeekAPIKeyPersistsInUserDefaults() {
        let suiteName = "DeepSeekAPIKeyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        XCTAssertNil(DeepSeekAPIKeyStore.load(from: defaults))
        DeepSeekAPIKeyStore.save("sk-local-test", to: defaults)
        XCTAssertEqual(DeepSeekAPIKeyStore.load(from: defaults), "sk-local-test")
    }

    func testFixedDeepSeekCurlCommandUsesAPIKeyAsArgumentSubstitution() throws {
        let command = try XCTUnwrap(DeepSeekBalanceClient.fixedCommand(apiKey: "test-key"))
        XCTAssertEqual(command.executableURL.path, "/usr/bin/curl")
        XCTAssertEqual(command.arguments, [
            "-L", "-X", "GET", "https://api.deepseek.com/user/balance",
            "-H", "Accept: application/json",
            "-H", "Authorization: Bearer test-key"
        ])
    }

    func testDeepSeekSettingsValidationRequiresKeyWhenEnabled() {
        XCTAssertEqual(
            DeepSeekSettingsValidation.validate(
                isEnabled: true,
                apiKey: "",
                curlTemplate: DeepSeekBalanceConfiguration.defaultCurlTemplate
            ),
            .missingAPIKey
        )
    }

    func testDeepSeekSettingsValidationAcceptsDisabledOrCompleteConfiguration() {
        XCTAssertEqual(
            DeepSeekSettingsValidation.validate(isEnabled: false, apiKey: "", curlTemplate: ""),
            .valid
        )
        XCTAssertEqual(
            DeepSeekSettingsValidation.validate(
                isEnabled: true,
                apiKey: "test-key",
                curlTemplate: DeepSeekBalanceConfiguration.defaultCurlTemplate
            ),
            .valid
        )
    }

    func testBrandIdentityUsesQuotaPulsePositioning() {
        XCTAssertEqual(AppBrand.name, "QuotaPulse")
        XCTAssertEqual(AppBrand.bundleIdentifier, "com.cmsjcm.QuotaPulse")
        XCTAssertEqual(AppBrand.preferenceNamespace, "QuotaPulse.v2")
        XCTAssertEqual(
            AppBrand.englishSubtitle,
            "A private, native quota, activity, and alert companion for Codex and Claude on macOS."
        )
        XCTAssertEqual(AppBrand.chineseSubtitle, "Codex 与 Claude 的本地额度、活动状态与提醒伴侣")
    }

    func testDecodesUsageAndComputesRemaining() throws {
        let json = #"[{"providerId":"codex","displayName":"Codex","plan":"Pro","lines":[{"type":"progress","label":"Session","used":17,"limit":100,"resetsAt":"2026-07-12T18:17:13.000Z","periodDurationMs":18000000}],"fetchedAt":"2026-07-12T15:44:43.909678Z"}]"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        let result = try decoder.decode([ProviderUsage].self, from: json)
        XCTAssertEqual(result[0].session?.remainingPercent, 0.83)
        XCTAssertNotNil(result[0].session?.resetsAt)
    }

    func testHealthThresholds() {
        XCTAssertEqual(QuotaHealth(remaining: 0.8), .healthy)
        XCTAssertEqual(QuotaHealth(remaining: 0.51), .healthy)
        XCTAssertEqual(QuotaHealth(remaining: 0.50), .warning)
        XCTAssertEqual(QuotaHealth(remaining: 0.11), .warning)
        XCTAssertEqual(QuotaHealth(remaining: 0.10), .critical)
    }

    func testWeeklyQuotaBudgetRequiresAnActiveValidPeriod() {
        let resetAt = Date(timeIntervalSince1970: 7 * 24 * 60 * 60)
        let durationMs = 7.0 * 24 * 60 * 60 * 1_000

        XCTAssertNil(WeeklyQuotaBudget.plannedRemaining(
            resetAt: resetAt,
            periodDurationMs: durationMs,
            now: Date(timeIntervalSince1970: 0)
        ))
        XCTAssertNil(WeeklyQuotaBudget.plannedRemaining(
            resetAt: resetAt,
            periodDurationMs: nil,
            now: Date(timeIntervalSince1970: 24 * 60 * 60)
        ))
    }

    func testWeeklyQuotaBudgetComputesPlannedRemainingOnTheRingScale() throws {
        let resetAt = Date(timeIntervalSince1970: 7 * 24 * 60 * 60)
        let durationMs = 7.0 * 24 * 60 * 60 * 1_000

        XCTAssertEqual(
            try XCTUnwrap(WeeklyQuotaBudget.plannedRemaining(
                resetAt: resetAt,
                periodDurationMs: durationMs,
                now: Date(timeIntervalSince1970: 1 * 24 * 60 * 60)
            )),
            6.0 / 7.0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            try XCTUnwrap(WeeklyQuotaBudget.plannedRemaining(
                resetAt: resetAt,
                periodDurationMs: durationMs,
                now: Date(timeIntervalSince1970: 4 * 24 * 60 * 60)
            )),
            3.0 / 7.0,
            accuracy: 0.001
        )
    }

    func testWeeklyQuotaPlanConfigurationDefaultsToSevenDaysAndPersistsWeekendChoice() throws {
        let suiteName = "WeeklyQuotaPlanTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertFalse(WeeklyQuotaPlanPreferences.load(from: defaults).excludesWeekends)
        WeeklyQuotaPlanPreferences.save(
            WeeklyQuotaPlanConfiguration(excludesWeekends: true),
            to: defaults
        )
        XCTAssertTrue(WeeklyQuotaPlanPreferences.load(from: defaults).excludesWeekends)

        defaults.set(
            Data("invalid".utf8),
            forKey: "QuotaPulse.v2.weeklyQuotaPlan.configuration"
        )
        XCTAssertFalse(WeeklyQuotaPlanPreferences.load(from: defaults).excludesWeekends)
    }

    func testWeeklyQuotaBudgetFreezesAcrossExcludedWeekend() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 7, day: 1
        )))
        let resetAt = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: start))
        let saturday = try XCTUnwrap(calendar.date(byAdding: .hour, value: 84, to: start))
        let sunday = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: saturday))

        for now in [saturday, sunday] {
            XCTAssertEqual(
                try XCTUnwrap(WeeklyQuotaBudget.plannedRemaining(
                    resetAt: resetAt,
                    periodDurationMs: 7 * 24 * 60 * 60 * 1_000,
                    excludingWeekends: true,
                    calendar: calendar,
                    now: now
                )),
                0.40,
                accuracy: 0.001
            )
        }
    }

    func testQuotaNotificationDetectsCrossedTenPercentBoundary() {
        XCTAssertEqual(
            QuotaNotificationPolicy.crossedThreshold(previous: 0.91, current: 0.89),
            0.90
        )
        XCTAssertNil(
            QuotaNotificationPolicy.crossedThreshold(previous: 0.89, current: 0.88)
        )
    }

    func testQuotaNotificationUsesLowestBoundaryWhenOneRefreshCrossesSeveral() {
        XCTAssertEqual(
            QuotaNotificationPolicy.crossedThreshold(previous: 0.91, current: 0.69),
            0.70
        )
    }

    func testQuotaNotificationDoesNotFireWhenQuotaResetsUpward() {
        XCTAssertNil(
            QuotaNotificationPolicy.crossedThreshold(previous: 0.09, current: 1.0)
        )
    }

    func testQuotaNotificationSupportsCustomSingleStageInterval() throws {
        let configuration = QuotaNotificationConfiguration.singleStage(intervalPercent: 7)

        XCTAssertTrue(configuration.isValid)
        XCTAssertEqual(
            try XCTUnwrap(QuotaNotificationPolicy.crossedThreshold(
                previous: 0.94,
                current: 0.92,
                configuration: configuration
            )),
            0.93,
            accuracy: 0.000_001
        )
    }

    func testQuotaNotificationSupportsTwoStageIntervals() throws {
        let configuration = QuotaNotificationConfiguration.twoStage(
            breakpointPercent: 50,
            firstIntervalPercent: 10,
            secondIntervalPercent: 5
        )

        XCTAssertTrue(configuration.isValid)
        XCTAssertEqual(configuration.remainingThresholdPercents, [90, 80, 70, 60, 50, 45, 40, 35, 30, 25, 20, 15, 10, 5])
        XCTAssertEqual(
            try XCTUnwrap(QuotaNotificationPolicy.crossedThreshold(
                previous: 0.52,
                current: 0.44,
                configuration: configuration
            )),
            0.45,
            accuracy: 0.000_001
        )
    }

    func testQuotaNotificationConfigurationRejectsUnreasonableNumbers() {
        XCTAssertFalse(QuotaNotificationConfiguration.singleStage(intervalPercent: 0).isValid)
        XCTAssertFalse(QuotaNotificationConfiguration.singleStage(intervalPercent: 100).isValid)
        XCTAssertFalse(QuotaNotificationConfiguration.singleStage(intervalPercent: 101).isValid)
        XCTAssertFalse(QuotaNotificationConfiguration.twoStage(
            breakpointPercent: 100,
            firstIntervalPercent: 10,
            secondIntervalPercent: 5
        ).isValid)
    }

    func testQuotaNotificationPreferencesDefaultsToTenPercentAndPersistsChanges() {
        let suiteName = "QuotaPulseTests.quota-notification"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(QuotaNotificationPreferences.load(from: defaults), .singleStage(intervalPercent: 10))

        let configuration = QuotaNotificationConfiguration.twoStage(
            breakpointPercent: 40,
            firstIntervalPercent: 8,
            secondIntervalPercent: 4
        )
        QuotaNotificationPreferences.save(configuration, to: defaults)

        XCTAssertEqual(QuotaNotificationPreferences.load(from: defaults), configuration)
    }

    func testDailyReminderBuildsRepeatingClockTime() {
        let reminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 21,
            minute: 35,
            message: "记得查看今天的额度"
        )

        XCTAssertEqual(reminder.triggerDateComponents?.hour, 21)
        XCTAssertEqual(reminder.triggerDateComponents?.minute, 35)
    }

    func testDailyReminderRequiresNonEmptyTrimmedMessage() {
        let valid = DailyReminderConfiguration(
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "  开始今天的工作  "
        )
        let empty = DailyReminderConfiguration(
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "  \n "
        )

        XCTAssertEqual(valid.normalizedMessage, "开始今天的工作")
        XCTAssertTrue(valid.isValid)
        XCTAssertFalse(empty.isValid)
    }

    func testDailyReminderPreferencesStoreMultipleReminders() {
        let suiteName = "QuotaPulseTests.multiple-reminders"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let reminders = [
            DailyReminderConfiguration(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                isEnabled: true,
                hour: 9,
                minute: 0,
                message: "上午提醒"
            ),
            DailyReminderConfiguration(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                isEnabled: false,
                hour: 18,
                minute: 30,
                message: "晚上提醒"
            )
        ]

        DailyReminderPreferences.saveAll(reminders, to: defaults)

        XCTAssertEqual(DailyReminderPreferences.loadAll(from: defaults), reminders)
    }

    func testDailyReminderPreferencesIgnoreRetiredStorageKeys() throws {
        let suiteName = "QuotaPulseTests.retired-reminder-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let retiredReminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 8,
            minute: 45,
            message: "Retired"
        )
        defaults.set(
            try JSONEncoder().encode([retiredReminder]),
            forKey: "retired.dailyReminders"
        )

        XCTAssertEqual(DailyReminderPreferences.loadAll(from: defaults), [])
    }

    func testDailyReminderAcceptsOnlyHTTPWebLinks() {
        let webReminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 10,
            minute: 0,
            message: "打开日报",
            actionType: .url,
            actionValue: "  https://example.com/daily  "
        )
        let unsafeReminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 10,
            minute: 0,
            message: "不要执行脚本",
            actionType: .url,
            actionValue: "javascript:alert(1)"
        )

        XCTAssertEqual(webReminder.destinationURL?.absoluteString, "https://example.com/daily")
        XCTAssertTrue(webReminder.isValid)
        XCTAssertNil(unsafeReminder.destinationURL)
        XCTAssertFalse(unsafeReminder.isValid)
    }

    func testDailyReminderRejectsDataMissingCurrentScheduleAndActionFields() {
        let json = #"[{"id":"11111111-1111-1111-1111-111111111111","isEnabled":true,"hour":9,"minute":0,"message":"Incomplete"}]"#.data(using: .utf8)!

        XCTAssertThrowsError(
            try JSONDecoder().decode([DailyReminderConfiguration].self, from: json)
        )
    }

    func testDailyReminderPreferencesRejectConditionallyIncompleteCurrentData() {
        let suiteName = "QuotaPulseTests.incomplete-current-reminders-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let incompleteReminders = [
            DailyReminderConfiguration(
                isEnabled: true, hour: 9, minute: 0, message: "Once", scheduleType: .once
            ),
            DailyReminderConfiguration(
                isEnabled: true, hour: 9, minute: 0, message: "Weekly", scheduleType: .weekly
            ),
            DailyReminderConfiguration(
                isEnabled: true, hour: 9, minute: 0, message: "URL", actionType: .url
            ),
            DailyReminderConfiguration(
                isEnabled: true,
                hour: 9,
                minute: 0,
                message: "Python",
                actionType: .python,
                actionValue: "/tmp/task.py"
            )
        ]

        for reminder in incompleteReminders {
            DailyReminderPreferences.saveAll([reminder], to: defaults)
            XCTAssertEqual(DailyReminderPreferences.loadAll(from: defaults), [])
        }
    }

    func testDailyReminderPreferencesDoNotOverwriteValidDataWithIncompleteDisabledReminder() {
        let suiteName = "QuotaPulseTests.reject-incomplete-save-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let valid = DailyReminderConfiguration(
            isEnabled: true, hour: 9, minute: 0, message: "Valid"
        )
        let incompleteDisabled = DailyReminderConfiguration(
            isEnabled: false,
            hour: 10,
            minute: 0,
            message: "Incomplete",
            actionType: .url
        )

        DailyReminderPreferences.saveAll([valid], to: defaults)
        DailyReminderPreferences.saveAll([valid, incompleteDisabled], to: defaults)

        XCTAssertEqual(DailyReminderPreferences.loadAll(from: defaults), [valid])
    }

    func testOneTimeReminderBuildsOneNonRepeatingSchedule() {
        let calendar = Calendar(identifier: .gregorian)
        let fireDate = Date(timeIntervalSince1970: 1_800_000_000)
        let reminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 0,
            minute: 0,
            message: "一次性提醒",
            scheduleType: .once,
            scheduledDate: fireDate
        )

        let schedules = reminder.notificationSchedules(
            now: fireDate.addingTimeInterval(-60),
            calendar: calendar
        )

        XCTAssertEqual(schedules.count, 1)
        XCTAssertFalse(schedules[0].repeats)
        XCTAssertEqual(schedules[0].dateComponents.year, calendar.component(.year, from: fireDate))
        XCTAssertEqual(schedules[0].dateComponents.minute, calendar.component(.minute, from: fireDate))
    }

    func testReminderListPrependsNewReminder() {
        let existing = DailyReminderConfiguration(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "已有提醒"
        )
        let newReminder = DailyReminderConfiguration(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            isEnabled: true,
            hour: 10,
            minute: 0,
            message: "新提醒"
        )

        let result = ReminderListPolicy.prepending(newReminder, to: [existing])

        XCTAssertEqual(result.map(\.id), [newReminder.id, existing.id])
    }

    func testReminderListKeepsAndDisablesCompletedOneTimeReminder() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let completed = DailyReminderConfiguration(
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "已完成提醒",
            scheduleType: .once,
            scheduledDate: now.addingTimeInterval(-60)
        )

        let result = ReminderListPolicy.preparingForDisplay([completed], at: now)

        XCTAssertEqual(result.count, 1)
        XCTAssertFalse(result[0].isEnabled)
        XCTAssertTrue(result[0].isCompleted(at: now))
    }

    func testWeeklyReminderBuildsOneRepeatingSchedulePerSelectedWeekday() {
        let reminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 8,
            minute: 30,
            message: "工作日提醒",
            scheduleType: .weekly,
            weekdays: [2, 3, 4, 5, 6]
        )

        let schedules = reminder.notificationSchedules()

        XCTAssertEqual(schedules.count, 5)
        XCTAssertEqual(Set(schedules.compactMap(\.dateComponents.weekday)), [2, 3, 4, 5, 6])
        XCTAssertTrue(schedules.allSatisfy(\.repeats))
    }

    func testPythonClickActionRequiresAbsoluteScriptAndWorkingDirectory() {
        let valid = DailyReminderConfiguration(
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "运行脚本",
            actionType: .python,
            actionValue: "/tmp/quotapulse-test/automation/report.py",
            workingDirectory: "/tmp/quotapulse-test/automation"
        )
        let unsafe = DailyReminderConfiguration(
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "运行脚本",
            actionType: .python,
            actionValue: "report.py",
            workingDirectory: "/tmp/quotapulse-test/automation"
        )

        XCTAssertEqual(
            valid.clickAction,
            .python(
                scriptPath: "/tmp/quotapulse-test/automation/report.py",
                workingDirectory: "/tmp/quotapulse-test/automation"
            )
        )
        XCTAssertTrue(valid.isValid)
        XCTAssertNil(unsafe.clickAction)
        XCTAssertFalse(unsafe.isValid)
    }

    func testReminderActionPayloadRoundTripsSupportedActions() throws {
        let actions: [ReminderClickAction] = [
            .none,
            .openURL(try XCTUnwrap(URL(string: "https://example.com"))),
            .openPath("/Applications/Notes.app"),
            .shortcut("开始专注"),
            .python(
                scriptPath: "/tmp/quotapulse-test/automation/report.py",
                workingDirectory: "/tmp/quotapulse-test/automation"
            )
        ]

        for action in actions {
            let payload = ReminderActionPayload(action: action)
            XCTAssertEqual(payload.clickAction, action)
        }
    }

    func testReminderActionDiagnosticLabelsDoNotExposeTargetValues() {
        let sensitiveTargets = [
            ReminderClickAction.openURL(URL(string: "https://private.example/secret")!),
            .openPath("/tmp/secret.txt"),
            .shortcut("Private Shortcut"),
            .python(scriptPath: "/tmp/secret.py", workingDirectory: "/tmp")
        ]

        XCTAssertEqual(
            sensitiveTargets.map(\.diagnosticLabel),
            ["openURL", "openPath", "shortcut", "python"]
        )
        for (action, target) in zip(
            sensitiveTargets,
            ["private.example", "secret.txt", "Private Shortcut", "secret.py"]
        ) {
            XCTAssertFalse(action.diagnosticLabel.contains(target))
        }
    }

    func testReminderSnoozeActionsMapToExpectedDelays() {
        XCTAssertEqual(ReminderSnoozePolicy.delay(for: "QuotaPulse.v2.snooze.10m"), 10 * 60)
        XCTAssertEqual(ReminderSnoozePolicy.delay(for: "QuotaPulse.v2.snooze.1h"), 60 * 60)
        XCTAssertNil(ReminderSnoozePolicy.delay(for: "unknown"))
    }

    @MainActor
    func testReminderClickActionRunsBeforeSystemResponseCompletion() throws {
        let action = ReminderClickAction.openURL(
            try XCTUnwrap(URL(string: "https://example.com/daily"))
        )
        var events: [String] = []

        ReminderResponseCompletion.perform(
            action,
            execute: { _ in events.append("action") },
            completion: { events.append("completion") }
        )

        XCTAssertEqual(events, ["action", "completion"])
    }

    func testReminderResponseRecoversActionFromCurrentConfigurationWhenPayloadIsMissing() throws {
        let id = try XCTUnwrap(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let reminder = DailyReminderConfiguration(
            id: id,
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "Open dashboard",
            actionType: .url,
            actionValue: "https://example.com/dashboard"
        )

        let action = ReminderResponseActionResolver.resolve(
            userInfo: [:],
            requestIdentifier: "\(reminder.notificationIdentifier).daily",
            configurations: [reminder]
        )

        XCTAssertEqual(
            action,
            .openURL(try XCTUnwrap(URL(string: "https://example.com/dashboard")))
        )
    }

    func testReminderResponseDoesNotRecoverActionForRetiredOrUnknownIdentifier() {
        let reminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "Open dashboard",
            actionType: .url,
            actionValue: "https://example.com/dashboard"
        )

        XCTAssertNil(ReminderResponseActionResolver.resolve(
            userInfo: ReminderActionPayload(action: .openURL(
                URL(string: "https://example.com/retired")!
            )).userInfo,
            requestIdentifier: "com.cmsjcm.QuotaPulse.daily-reminder.retired.daily",
            configurations: [reminder]
        ))
        XCTAssertNil(ReminderResponseActionResolver.resolve(
            userInfo: [:],
            requestIdentifier: "unrelated.notification",
            configurations: [reminder]
        ))
    }

    func testShortcutActionBuildsShortcutsProcessCommand() throws {
        let command = try XCTUnwrap(
            ReminderActionExecutor.processCommand(for: .shortcut("开始专注"))
        )

        XCTAssertEqual(command.executableURL.path, "/usr/bin/shortcuts")
        XCTAssertEqual(command.arguments, ["run", "开始专注"])
        XCTAssertNil(command.currentDirectoryURL)
    }

    func testPythonActionBuildsDirectProcessWithoutShell() throws {
        let command = try XCTUnwrap(ReminderActionExecutor.processCommand(
            for: .python(
                scriptPath: "/tmp/quotapulse-test/automation/report.py",
                workingDirectory: "/tmp/quotapulse-test/automation"
            )
        ))

        XCTAssertEqual(command.executableURL.path, "/usr/bin/env")
        XCTAssertEqual(command.arguments, ["python3", "/tmp/quotapulse-test/automation/report.py"])
        XCTAssertEqual(command.currentDirectoryURL?.path, "/tmp/quotapulse-test/automation")
        XCTAssertTrue(command.environment["PATH", default: ""].contains("/opt/homebrew/bin"))
    }

    @MainActor
    func testReminderEditorProvidesExplicitChineseFieldLabels() {
        let language = LanguageSettings()
        language.language = .simplifiedChinese

        XCTAssertEqual(language.text("settings.reminder.message"), "通知内容")
        XCTAssertEqual(language.text("settings.reminder.url"), "点击后打开")
        XCTAssertEqual(language.text("settings.reminder.schedule"), "提醒计划")
        XCTAssertEqual(language.text("settings.reminder.action"), "点击动作")
    }

    func testCreditsRemainCreditsAndAreNotResetOpportunities() throws {
        let json = #"[{"providerId":"codex","displayName":"Codex","lines":[{"type":"progress","label":"Credits","used":1000,"limit":1000}]}]"#.data(using: .utf8)!
        let result = try JSONDecoder().decode([ProviderUsage].self, from: json)
        XCTAssertEqual(result[0].credits?.used, 1000)
    }

    func testHidesSuspendedCodexSessionAndKeepsSparkWeekly() throws {
        let json = #"[{"providerId":"codex","displayName":"Codex","lines":[{"type":"progress","label":"Session","used":12,"limit":100,"resetsAt":"2026-07-19T23:30:08.000Z","periodDurationMs":18000000},{"type":"progress","label":"Spark","used":20,"limit":100,"resetsAt":"2026-07-20T23:30:08.000Z","periodDurationMs":604800000}],"fetchedAt":"2026-07-12T23:30:09.000Z"}]"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        let provider = try decoder.decode([ProviderUsage].self, from: json)[0]
        XCTAssertNil(provider.session)
        XCTAssertEqual(provider.weekly?.remainingPercent, 0.88)
        XCTAssertEqual(provider.effectiveResetAt(for: provider.weekly!), provider.weekly?.resetsAt)
    }

    func testRestoresCodexSessionWhenShortWindowIsValid() throws {
        let json = #"[{"providerId":"codex","displayName":"Codex","lines":[{"type":"progress","label":"Session","used":12,"limit":100,"resetsAt":"2026-07-13T04:30:08.000Z","periodDurationMs":18000000}],"fetchedAt":"2026-07-13T01:30:09.000Z"}]"#.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
        let provider = try decoder.decode([ProviderUsage].self, from: json)[0]
        XCTAssertEqual(provider.session?.remainingPercent, 0.88)
    }

    func testMapsLiveWeatherIntoDistinctAnimationMoods() {
        let now = Date.now
        let fog = WeatherSnapshot(locationName: "测试城市", temperature: 25, code: 45, isDay: true, liveCondition: nil, fetchedAt: now)
        let rain = WeatherSnapshot(locationName: "测试城市", temperature: 24, code: 61, isDay: true, liveCondition: nil, fetchedAt: now)
        let storm = WeatherSnapshot(locationName: "测试城市", temperature: 23, code: 95, isDay: false, liveCondition: nil, fetchedAt: now)
        let snow = WeatherSnapshot(locationName: "测试城市", temperature: 0, code: 71, isDay: true, liveCondition: nil, fetchedAt: now)

        XCTAssertEqual(fog.mood, .fog)
        XCTAssertEqual(rain.mood, .rain)
        XCTAssertEqual(storm.mood, .storm)
        XCTAssertEqual(snow.mood, .snow)
    }

    func testActivityHighlightExpiresQuicklyAfterStreamingStops() {
        let now = Date.now
        XCTAssertTrue(ActivityDetectionPolicy.isActive(modifiedAt: now.addingTimeInterval(-3), now: now))
        XCTAssertFalse(ActivityDetectionPolicy.isActive(modifiedAt: now.addingTimeInterval(-5), now: now))
        XCTAssertFalse(ActivityDetectionPolicy.isActive(modifiedAt: now.addingTimeInterval(5), now: now))
    }

    func testRefreshesClaudeCredentialBeforeItActuallyExpires() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let insideLeeway = Int64(now.addingTimeInterval(4 * 60).timeIntervalSince1970 * 1_000)
        let safelyValid = Int64(now.addingTimeInterval(6 * 60).timeIntervalSince1970 * 1_000)

        XCTAssertTrue(ClaudeCredentialPolicy.shouldRefresh(expiresAtMilliseconds: insideLeeway, now: now))
        XCTAssertFalse(ClaudeCredentialPolicy.shouldRefresh(expiresAtMilliseconds: safelyValid, now: now))
        XCTAssertFalse(ClaudeCredentialPolicy.shouldRefresh(expiresAtMilliseconds: nil, now: now))
    }

    func testRejectsStaleLocationsAndSelectsTheMostAccurateFreshFix() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let stale = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 29.2, longitude: 120.2),
            altitude: 0,
            horizontalAccuracy: 20,
            verticalAccuracy: -1,
            timestamp: now.addingTimeInterval(-120)
        )
        let coarse = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 29.3, longitude: 120.3),
            altitude: 0,
            horizontalAccuracy: 900,
            verticalAccuracy: -1,
            timestamp: now.addingTimeInterval(-2)
        )
        let precise = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 29.4, longitude: 120.4),
            altitude: 0,
            horizontalAccuracy: 80,
            verticalAccuracy: -1,
            timestamp: now.addingTimeInterval(-3)
        )

        let selected = LocationSelectionPolicy.bestLocation(in: [stale, coarse, precise], now: now)
        XCTAssertEqual(selected?.coordinate.latitude, precise.coordinate.latitude)
        XCTAssertTrue(LocationSelectionPolicy.isPreciseEnough(precise))
        XCTAssertFalse(LocationSelectionPolicy.isPreciseEnough(coarse))
    }

    func testPrefersDistrictLevelWeatherLocationOverItsParentCity() {
        XCTAssertEqual(
            LocationNamePolicy.displayName(
                district: "示例新区",
                city: "示例市",
                province: "示例省",
                fallback: "当前位置"
            ),
            "示例"
        )
    }
}
