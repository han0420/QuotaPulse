import Foundation
import CoreLocation
import XCTest
@testable import QuotaDot

final class QuotaModelsTests: XCTestCase {
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
        let suiteName = "QuotaDotTests.quota-notification"
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
        let suiteName = "QuotaDotTests.multiple-reminders"
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

    func testDailyReminderPreferencesMigratesLegacyReminder() {
        let suiteName = "QuotaDotTests.legacy-reminder"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: "QuotaDot.dailyReminder.enabled")
        defaults.set(8, forKey: "QuotaDot.dailyReminder.hour")
        defaults.set(45, forKey: "QuotaDot.dailyReminder.minute")
        defaults.set("旧提醒", forKey: "QuotaDot.dailyReminder.message")

        let migrated = DailyReminderPreferences.loadAll(from: defaults)

        XCTAssertEqual(migrated.count, 1)
        XCTAssertEqual(migrated[0].hour, 8)
        XCTAssertEqual(migrated[0].minute, 45)
        XCTAssertEqual(migrated[0].message, "旧提醒")
    }

    func testDailyReminderAcceptsOnlyHTTPWebLinks() {
        let webReminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 10,
            minute: 0,
            message: "打开日报",
            urlString: "  https://example.com/daily  "
        )
        let unsafeReminder = DailyReminderConfiguration(
            isEnabled: true,
            hour: 10,
            minute: 0,
            message: "不要执行脚本",
            urlString: "javascript:alert(1)"
        )

        XCTAssertEqual(webReminder.destinationURL?.absoluteString, "https://example.com/daily")
        XCTAssertTrue(webReminder.isValid)
        XCTAssertNil(unsafeReminder.destinationURL)
        XCTAssertFalse(unsafeReminder.isValid)
    }

    func testDailyReminderDecodesSavedDataWithoutURL() throws {
        let json = #"[{"id":"11111111-1111-1111-1111-111111111111","isEnabled":true,"hour":9,"minute":0,"message":"旧数据"}]"#.data(using: .utf8)!

        let reminders = try JSONDecoder().decode([DailyReminderConfiguration].self, from: json)

        XCTAssertNil(reminders[0].urlString)
        XCTAssertTrue(reminders[0].isValid)
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

    func testLegacyURLReminderDefaultsToDailyOpenURLAction() throws {
        let json = #"{"id":"11111111-1111-1111-1111-111111111111","isEnabled":true,"hour":9,"minute":0,"message":"旧数据","urlString":"https://example.com"}"#.data(using: .utf8)!

        let reminder = try JSONDecoder().decode(DailyReminderConfiguration.self, from: json)

        XCTAssertEqual(reminder.effectiveScheduleType, .daily)
        XCTAssertEqual(reminder.effectiveActionType, .url)
        XCTAssertEqual(reminder.effectiveActionValue, "https://example.com")
    }

    func testPythonClickActionRequiresAbsoluteScriptAndWorkingDirectory() {
        let valid = DailyReminderConfiguration(
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "运行脚本",
            actionType: .python,
            actionValue: "/Users/example/automation/report.py",
            workingDirectory: "/Users/example/automation"
        )
        let unsafe = DailyReminderConfiguration(
            isEnabled: true,
            hour: 9,
            minute: 0,
            message: "运行脚本",
            actionType: .python,
            actionValue: "report.py",
            workingDirectory: "/Users/example/automation"
        )

        XCTAssertEqual(
            valid.clickAction,
            .python(
                scriptPath: "/Users/example/automation/report.py",
                workingDirectory: "/Users/example/automation"
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
                scriptPath: "/Users/example/automation/report.py",
                workingDirectory: "/Users/example/automation"
            )
        ]

        for action in actions {
            let payload = ReminderActionPayload(action: action)
            XCTAssertEqual(payload.clickAction, action)
        }
    }

    func testReminderSnoozeActionsMapToExpectedDelays() {
        XCTAssertEqual(ReminderSnoozePolicy.delay(for: "QuotaDot.snooze.10m"), 10 * 60)
        XCTAssertEqual(ReminderSnoozePolicy.delay(for: "QuotaDot.snooze.1h"), 60 * 60)
        XCTAssertNil(ReminderSnoozePolicy.delay(for: "unknown"))
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
                scriptPath: "/Users/example/automation/report.py",
                workingDirectory: "/Users/example/automation"
            )
        ))

        XCTAssertEqual(command.executableURL.path, "/usr/bin/env")
        XCTAssertEqual(command.arguments, ["python3", "/Users/example/automation/report.py"])
        XCTAssertEqual(command.currentDirectoryURL?.path, "/Users/example/automation")
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
