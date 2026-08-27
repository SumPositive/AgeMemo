// 和暦・干支・年齢・飛躍換算の基礎ロジックを検証する

import XCTest
@testable import AgeMemo

final class CoreLogicTests: XCTestCase {
    func testJapaneseEraExamples() {
        let expected = [
            1600: "慶長5年",
            1700: "元禍13年",
            1800: "寛政12年",
            2026: "令和8年",
            2100: "令和82年",
        ]

        for (year, displayText) in expected {
            XCTAssertEqual(JapaneseEra.spans(in: year).map(\.displayText).joined(separator: "/"), displayText)
        }
    }

    func testEraTransitionDates() {
        let transitions = JapaneseEra.makeRows().flatMap { row in
            row.eraSpans.dropFirst().map { (row.gregorian, $0.startMonth, $0.startDay) }
        }
        XCTAssertEqual(transitions.count, 40)
        XCTAssertTrue(transitions.contains { $0 == (2019, 5, 1) })
        XCTAssertTrue(transitions.contains { $0 == (1989, 1, 8) })
    }

    func testZodiacExamples() {
        XCTAssertEqual(StemBranch.value(for: 1600).kanji, "庚子")
        XCTAssertEqual(StemBranch.value(for: 1868).kanji, "戊辰")
        XCTAssertEqual(StemBranch.value(for: 1926).kanji, "丙寅")
        XCTAssertEqual(StemBranch.value(for: 2026).kanji, "丙午")
        XCTAssertEqual(StemBranch.value(for: 2100).kanji, "庚申")
    }

    func testAgeBeforeAndAfterBirthYear() throws {
        let birthDate = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(year: 1988, month: 6, day: 1)))
        XCTAssertEqual(AgeCalculator.age(in: 1986, birthDate: birthDate), -2)
        XCTAssertEqual(AgeCalculator.age(in: 1988, birthDate: birthDate), 0)
        XCTAssertEqual(AgeCalculator.age(in: 2026, birthDate: birthDate), 38)
        XCTAssertNil(AgeCalculator.age(in: 2026, birthDate: nil))
    }

    func testEraChoiceUsesActualFirstYear() throws {
        let choices = JapaneseEra.eraChoices(from: JapaneseEra.makeRows())
        let keicho = try XCTUnwrap(choices.first { $0.name == "慶長" })
        XCTAssertEqual(keicho.firstGregorianYear, 1596)
    }
}
