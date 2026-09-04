// 和暦・干支・年齢・移動換算の基礎ロジックを検証する

import XCTest
@testable import AgeMemo

final class CoreLogicTests: XCTestCase {
    func testJapaneseEraExamples() {
        let expected = [
            1600: "慶長5年",
            1700: "元禄13年",
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

    func testAgeModeUsesRowYearAsBirthYear() {
        XCTAssertEqual(
            AgeCalculator.displayedAge(
                for: 2026,
                mode: .age,
                birthDate: nil,
                currentYear: 2026
            ),
            0
        )
        XCTAssertEqual(
            AgeCalculator.displayedAge(
                for: 2027,
                mode: .age,
                birthDate: nil,
                currentYear: 2026
            ),
            -1
        )
    }

    func testPersonModeUsesPersonBirthDate() {
        let birthDate = Calendar(identifier: .gregorian)
            .date(from: DateComponents(year: 1950, month: 5, day: 3))!
        XCTAssertEqual(
            AgeCalculator.displayedAge(
                for: 2026,
                mode: .person,
                birthDate: birthDate,
                currentYear: 2026
            ),
            76
        )
    }

    func testBirthYearForAge() {
        XCTAssertEqual(AgeCalculator.birthYear(forAge: 38, currentYear: 2026), 1988)
        XCTAssertEqual(AgeCalculator.birthYear(forAge: 0, currentYear: 2026), 2026)
        XCTAssertEqual(AgeCalculator.birthYear(forAge: -1, currentYear: 2026), 2027)
    }

    func testYearForPersonalAge() throws {
        let birthDate = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1988, month: 6, day: 1))
        )
        XCTAssertEqual(AgeCalculator.year(forAge: 10, birthDate: birthDate), 1998)
        XCTAssertEqual(AgeCalculator.year(forAge: 0, birthDate: birthDate), 1988)
        XCTAssertEqual(AgeCalculator.year(forAge: -2, birthDate: birthDate), 1986)
    }

    /// 記念日は登録年を0周年として前年・登録年・翌年を数える
    func testAnniversaryCount() throws {
        let startDate = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1995, month: 3, day: 2))
        )
        XCTAssertEqual(AgeCalculator.anniversaryCount(for: 1994, startDate: startDate), -1)
        XCTAssertEqual(AgeCalculator.anniversaryCount(for: 1995, startDate: startDate), 0)
        XCTAssertEqual(AgeCalculator.anniversaryCount(for: 1996, startDate: startDate), 1)
    }

    /// 記念日一覧の周年指定を登録年から西暦年へ逆算する
    func testYearForAnniversaryJump() throws {
        let startDate = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 1995, month: 3, day: 2))
        )
        XCTAssertEqual(AgeCalculator.year(forAnniversary: 0, startDate: startDate), 1995)
        XCTAssertEqual(AgeCalculator.year(forAnniversary: 31, startDate: startDate), 2026)
        XCTAssertEqual(AgeCalculator.year(forAnniversary: -1, startDate: startDate), 1994)
    }

    /// 誕生日前・当日・誕生日後で今日時点の満年齢が切り替わる
    func testCurrentActualAgeAroundBirthday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 1995, month: 3, day: 2)))
        let before = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        let birthday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 2)))
        let after = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 3)))

        XCTAssertEqual(AgeCalculator.currentActualAge(birthDate: birthDate, today: before), 30)
        XCTAssertEqual(AgeCalculator.currentActualAge(birthDate: birthDate, today: birthday), 31)
        XCTAssertEqual(AgeCalculator.currentActualAge(birthDate: birthDate, today: after), 31)
        XCTAssertTrue(AgeCalculator.isBeforeBirthday(birthDate: birthDate, today: before))
        XCTAssertFalse(AgeCalculator.isBeforeBirthday(birthDate: birthDate, today: birthday))
        XCTAssertFalse(AgeCalculator.isBeforeBirthday(birthDate: birthDate, today: after))
    }

    /// 2月29日生まれはうるう年の誕生日当日に満年齢が切り替わる
    func testLeapDayBirthday() throws {
        let calendar = Calendar(identifier: .gregorian)
        let birthDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2000, month: 2, day: 29)))
        let before = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 28)))
        let birthday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 29)))

        XCTAssertEqual(AgeCalculator.currentActualAge(birthDate: birthDate, today: before), 23)
        XCTAssertEqual(AgeCalculator.currentActualAge(birthDate: birthDate, today: birthday), 24)
        XCTAssertTrue(AgeCalculator.isBeforeBirthday(birthDate: birthDate, today: before))
        XCTAssertFalse(AgeCalculator.isBeforeBirthday(birthDate: birthDate, today: birthday))
    }

    /// 数え年は生まれた時点で1歳、以後元日ごとに1つ増える
    func testTraditionalAgeConversion() {
        XCTAssertEqual(AgeCalculator.traditionalAge(fromActual: 0), 1)
        XCTAssertEqual(AgeCalculator.traditionalAge(fromActual: 60), 61)
        // 生まれる前は数え年の考え方が当てはまらないのでそのまま返す
        XCTAssertEqual(AgeCalculator.traditionalAge(fromActual: -1), -1)
        XCTAssertEqual(AgeCalculator.actualAge(fromTraditional: 61), 60)
        XCTAssertEqual(AgeCalculator.actualAge(fromTraditional: 1), 0)
    }

    /// 賀寿と厄年はもともと数え年で見るため、満年齢から1つずらして判定する
    func testLongevityAndUnluckyYearUseTraditionalAge() {
        XCTAssertEqual(Longevity.forActualAge(60)?.name, "還暦")
        XCTAssertNil(Longevity.forActualAge(61))
        // 男性の本厄42歳（数え）は満41歳の行に出る
        XCTAssertEqual(UnluckyYear.forActualAge(41, gender: .male)?.phase, .main)
        XCTAssertEqual(UnluckyYear.forActualAge(41, gender: .male)?.isMajor, true)
    }

    func testEraChoiceUsesActualFirstYear() throws {
        let choices = JapaneseEra.eraChoices(from: JapaneseEra.makeRows())
        let keicho = try XCTUnwrap(choices.first { $0.name == "慶長" })
        XCTAssertEqual(keicho.firstGregorianYear, 1596)
    }

    func testSchoolGradeFromElementaryToUniversity() throws {
        // 小学校入学年から大学4年までを各年の学年表記へ変換する
        let birthDate = try XCTUnwrap(
            Calendar(identifier: .gregorian)
                .date(from: DateComponents(year: 2018, month: 4, day: 2))
        )
        XCTAssertEqual(SchoolAge.milestone(inYear: 2025, birthDate: birthDate)?.shortName, "小1")
        XCTAssertEqual(SchoolAge.milestone(inYear: 2030, birthDate: birthDate)?.shortName, "小6")
        XCTAssertEqual(SchoolAge.milestone(inYear: 2031, birthDate: birthDate)?.shortName, "中1")
        XCTAssertEqual(SchoolAge.milestone(inYear: 2034, birthDate: birthDate)?.shortName, "高1")
        XCTAssertEqual(SchoolAge.milestone(inYear: 2037, birthDate: birthDate)?.shortName, "大1")
        XCTAssertEqual(SchoolAge.milestone(inYear: 2040, birthDate: birthDate)?.shortName, "大4")
        XCTAssertNil(SchoolAge.milestone(inYear: 2041, birthDate: birthDate))
    }
}
