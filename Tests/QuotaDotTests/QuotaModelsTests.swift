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
