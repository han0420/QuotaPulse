import AppKit
import Foundation
import SwiftUI
import XCTest
@testable import QuotaPulse

final class QuotaResetDisplayTests: XCTestCase {
    @MainActor
    func testCompactResetCountdownFormatsDaysAndHoursInBothLanguages() {
        let language = LanguageSettings()
        let originalLanguage = language.language
        defer { language.language = originalLanguage }
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let resetAt = now.addingTimeInterval((6 * 24 + 23) * 60 * 60 + 30 * 60)

        language.language = .english
        XCTAssertEqual(
            QuotaFormatters.compactResetCountdown(from: resetAt, language: language, now: now),
            "6d 23h left"
        )

        language.language = .simplifiedChinese
        XCTAssertEqual(
            QuotaFormatters.compactResetCountdown(from: resetAt, language: language, now: now),
            "还有6天23小时"
        )
    }

    @MainActor
    func testCompactResetCountdownFormatsHoursMinutesAndMinutesInBothLanguages() {
        let language = LanguageSettings()
        let originalLanguage = language.language
        defer { language.language = originalLanguage }
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let hoursReset = now.addingTimeInterval(2 * 60 * 60 + 45 * 60 + 59)
        let minutesReset = now.addingTimeInterval(42 * 60 + 59)

        language.language = .english
        XCTAssertEqual(
            QuotaFormatters.compactResetCountdown(from: hoursReset, language: language, now: now),
            "2h 45m left"
        )
        XCTAssertEqual(
            QuotaFormatters.compactResetCountdown(from: minutesReset, language: language, now: now),
            "42m left"
        )

        language.language = .simplifiedChinese
        XCTAssertEqual(
            QuotaFormatters.compactResetCountdown(from: hoursReset, language: language, now: now),
            "还有2小时45分钟"
        )
        XCTAssertEqual(
            QuotaFormatters.compactResetCountdown(from: minutesReset, language: language, now: now),
            "还有42分钟"
        )
    }

    @MainActor
    func testCompactResetCountdownHidesAtAndAfterReset() {
        let language = LanguageSettings()
        let now = Date(timeIntervalSince1970: 2_000_000_000)

        XCTAssertNil(QuotaFormatters.compactResetCountdown(from: now, language: language, now: now))
        XCTAssertNil(
            QuotaFormatters.compactResetCountdown(
                from: now.addingTimeInterval(-1),
                language: language,
                now: now
            )
        )
    }

    @MainActor
    func testCompactResetLabelsFitAOneHundredThirtyNinePointQuotaColumn() {
        let english = NSHostingView(rootView: QuotaResetLabel(
            text: "Resets Aug 20, 01:04 · 6d 23h left",
            compact: true
        ).fixedSize())
        let chinese = NSHostingView(rootView: QuotaResetLabel(
            text: "8月20日 01:04 重置 · 还有6天23小时",
            compact: true
        ).fixedSize())

        XCTAssertLessThanOrEqual(english.fittingSize.width, 139)
        XCTAssertLessThanOrEqual(chinese.fittingSize.width, 139)
    }
}
