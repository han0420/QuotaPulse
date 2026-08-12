import AppKit
import Foundation
import SwiftUI
import XCTest
@testable import QuotaPulse

final class WorldClockDisplayTests: XCTestCase {
    @MainActor
    func testLocalizesBothWorldClockLabels() {
        let language = LanguageSettings()
        let originalLanguage = language.language
        defer { language.language = originalLanguage }

        language.language = .simplifiedChinese
        XCTAssertEqual(language.text("clock.local"), "当地时间")
        XCTAssertEqual(language.text("clock.unitedStates"), "美国时间")

        language.language = .english
        XCTAssertEqual(language.text("clock.local"), "Local time")
        XCTAssertEqual(language.text("clock.unitedStates"), "U.S. time")
    }

    @MainActor
    func testLocalizesWorldClockDateRelations() {
        let language = LanguageSettings()
        let originalLanguage = language.language
        defer { language.language = originalLanguage }

        language.language = .simplifiedChinese
        XCTAssertEqual(language.text(WorldClockDateRelation.yesterday.localizationKey), "昨天")
        XCTAssertEqual(language.text(WorldClockDateRelation.today.localizationKey), "今天")
        XCTAssertEqual(language.text(WorldClockDateRelation.tomorrow.localizationKey), "明天")

        language.language = .english
        XCTAssertEqual(language.text(WorldClockDateRelation.yesterday.localizationKey), "Yesterday")
        XCTAssertEqual(language.text(WorldClockDateRelation.today.localizationKey), "Today")
        XCTAssertEqual(language.text(WorldClockDateRelation.tomorrow.localizationKey), "Tomorrow")
    }

    func testFormatsPacificStandardTimeAlongsideLocalTime() throws {
        let shanghai = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))

        let times = WorldClockDisplay.times(
            at: date,
            localTimeZone: shanghai,
            language: .simplifiedChinese
        )

        XCTAssertEqual(times.local, "20:00")
        XCTAssertEqual(times.unitedStates, "04:00")
    }

    func testAutomaticallyUsesPacificDaylightSavingTime() throws {
        let shanghai = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z"))

        let times = WorldClockDisplay.times(
            at: date,
            localTimeZone: shanghai,
            language: .english
        )

        XCTAssertEqual(times.local, "20:00")
        XCTAssertEqual(times.unitedStates, "05:00")
        XCTAssertEqual(WorldClockDisplay.unitedStatesTimeZoneIdentifier, "America/Los_Angeles")
    }

    func testFormatsEachWeekdayInItsOwnTimeZoneAcrossTheDateBoundary() throws {
        let shanghai = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-13T00:15:00Z"))

        let times = WorldClockDisplay.times(
            at: date,
            localTimeZone: shanghai,
            language: .simplifiedChinese
        )

        XCTAssertEqual(times.localWeekday, "周四")
        XCTAssertEqual(times.local, "08:15")
        XCTAssertEqual(times.unitedStatesWeekday, "周三")
        XCTAssertEqual(times.unitedStates, "17:15")
    }

    func testMarksUnitedStatesAsYesterdayRelativeToShanghai() throws {
        let shanghai = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-13T00:15:00Z"))

        let times = WorldClockDisplay.times(
            at: date,
            localTimeZone: shanghai,
            language: .simplifiedChinese
        )

        XCTAssertEqual(times.localDateRelation, .today)
        XCTAssertEqual(times.unitedStatesDateRelation, .yesterday)
    }

    func testMarksUnitedStatesAsTomorrowWhenLocalDateIsBehindPacificTime() throws {
        let honolulu = try XCTUnwrap(TimeZone(identifier: "Pacific/Honolulu"))
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-13T07:30:00Z"))

        let times = WorldClockDisplay.times(
            at: date,
            localTimeZone: honolulu,
            language: .english
        )

        XCTAssertEqual(times.localDateRelation, .today)
        XCTAssertEqual(times.unitedStatesDateRelation, .tomorrow)
    }

    func testHidesDateRelationsWhenBothClocksShareTheSameDate() throws {
        let shanghai = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))
        let date = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-08-13T12:00:00Z"))

        let times = WorldClockDisplay.times(
            at: date,
            localTimeZone: shanghai,
            language: .simplifiedChinese
        )

        XCTAssertNil(times.localDateRelation)
        XCTAssertNil(times.unitedStatesDateRelation)
    }

    @MainActor
    func testEnglishCrossDateClockItemsFitThePanelWithoutCompressingText() {
        let local = NSHostingView(rootView: WorldClockItem(
            title: "Local time",
            time: "Thu 01:33",
            dateRelation: "Today",
            systemImage: "clock"
        ).fixedSize())
        let unitedStates = NSHostingView(rootView: WorldClockItem(
            title: "U.S. time",
            time: "Wed 17:33",
            dateRelation: "Yesterday",
            systemImage: "globe.americas"
        ).fixedSize())
        let requiredWidth = local.fittingSize.width
            + unitedStates.fittingSize.width
            + WorldClockBarLayout.dividerWidth
            + WorldClockBarLayout.sectionSpacing * 2
        let availableWidth = 356 - WorldClockBarLayout.horizontalPadding * 2

        XCTAssertLessThanOrEqual(requiredWidth, availableWidth)
        XCTAssertLessThanOrEqual(
            max(local.fittingSize.height, unitedStates.fittingSize.height),
            FloatingWindowLayout.worldClockHeight
        )
    }
}
