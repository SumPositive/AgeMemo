// 旧暦・六曜・月の満ち欠けの回帰テスト
// 期待値は国立天文台の公表値（暦要項の朔弦望、東京の正午月齢）と、一般的なカレンダーの六曜の決まりから取る

import XCTest
@testable import AgeMemo

final class LunarCalendarTests: XCTestCase {
    /// 旧暦の各月1日の六曜。1月・7月は先勝、2月・8月は友引…と月の番号で決まる
    private static let firstDayRokuyo: [Rokuyo] = [.sensho, .tomobiki, .sakimake, .butsumetsu, .taian, .shakko]

    /// 六曜の並び。先勝→友引→先負→仏滅→大安→赤口→先勝…と繰り返す
    private static let rokuyoOrder: [Rokuyo] = [.sensho, .tomobiki, .sakimake, .butsumetsu, .taian, .shakko]

    private static func expectedRokuyo(lunarMonth: Int, lunarDay: Int) -> Rokuyo {
        let first = firstDayRokuyo[(lunarMonth - 1) % 6]
        let start = rokuyoOrder.firstIndex(of: first)!
        return rokuyoOrder[(start + lunarDay - 1) % 6]
    }

    private static let daysInMonth2026 = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    // MARK: - 2026年の朔と望（国立天文台 暦要項）

    /// 2026年の朔（新月の瞬間）を含む日と、その日に始まる旧暦の月
    private static let newMoons2026: [(month: Int, day: Int, lunarMonth: Int)] = [
        (1, 19, 12), (2, 17, 1), (3, 19, 2), (4, 17, 3), (5, 17, 4), (6, 15, 5),
        (7, 14, 6), (8, 13, 7), (9, 11, 8), (10, 11, 9), (11, 9, 10), (12, 9, 11),
    ]

    /// 2026年の望（満月の瞬間）を含む日
    private static let fullMoons2026: [(month: Int, day: Int)] = [
        (1, 3), (2, 2), (3, 3), (4, 2), (5, 2), (5, 31), (6, 30),
        (7, 29), (8, 28), (9, 27), (10, 26), (11, 24), (12, 24),
    ]

    func testNewMoonDays2026AreFirstLunarDays() {
        for newMoon in Self.newMoons2026 {
            let lunar = LunarDate(year: 2026, month: newMoon.month, day: newMoon.day)
            XCTAssertEqual(lunar?.month, newMoon.lunarMonth, "\(newMoon)")
            XCTAssertEqual(lunar?.day, 1, "\(newMoon)")
        }
        // 朔の日以外に旧暦の1日はない
        var firstDays: [String] = []
        for month in 1...12 {
            for day in 1...Self.daysInMonth2026[month - 1] where LunarDate(year: 2026, month: month, day: day)?.day == 1 {
                firstDays.append("\(month)/\(day)")
            }
        }
        XCTAssertEqual(firstDays, Self.newMoons2026.map { "\($0.month)/\($0.day)" })
    }

    func testFullMoonDays2026() {
        var fullMoonDays: [String] = []
        for month in 1...12 {
            for day in 1...Self.daysInMonth2026[month - 1] where MoonPhase(year: 2026, month: month, day: day)?.isFullMoon == true {
                fullMoonDays.append("\(month)/\(day)")
            }
        }
        XCTAssertEqual(fullMoonDays, Self.fullMoons2026.map { "\($0.month)/\($0.day)" })
        for fullMoon in Self.fullMoons2026 {
            XCTAssertEqual(MoonPhase(year: 2026, month: fullMoon.month, day: fullMoon.day)?.illuminationPercent, 100)
        }
    }

    // MARK: - 六曜

    func testRokuyoAtStartAndEndOfLunarMonths2026() {
        for newMoon in Self.newMoons2026 {
            // 月初は月の番号で決まる六曜から始まる
            XCTAssertEqual(
                Rokuyo(year: 2026, month: newMoon.month, day: newMoon.day),
                Self.firstDayRokuyo[(newMoon.lunarMonth - 1) % 6],
                "\(newMoon)"
            )
            // 前日は前の月の末日（29日か30日）で、前の月の並びを続けた六曜になる
            let previousMonth = newMoon.day == 1 ? newMoon.month - 1 : newMoon.month
            let previousDay = newMoon.day == 1 ? Self.daysInMonth2026[previousMonth - 1] : newMoon.day - 1
            guard let lastDay = LunarDate(year: 2026, month: previousMonth, day: previousDay) else {
                XCTFail("\(newMoon)")
                continue
            }
            XCTAssertTrue([29, 30].contains(lastDay.day), "\(newMoon)")
            XCTAssertEqual(
                Rokuyo(year: 2026, month: previousMonth, day: previousDay),
                Self.expectedRokuyo(lunarMonth: lastDay.month, lunarDay: lastDay.day),
                "\(newMoon)"
            )
        }
        // 一般的なカレンダーの2026年10月の先負
        let sakimakeDays = (1...31).filter { Rokuyo(year: 2026, month: 10, day: $0) == .sakimake }
        XCTAssertEqual(sakimakeDays, [6, 11, 17, 23, 29])
    }

    func testRokuyoAtStartOfLeapMonths() {
        // 閏月の1日は元の月と同じ六曜から始まる。日本の閏月の位置は中国と違う年がある（2012年・2017年など）
        let leapMonthStarts: [(year: Int, month: Int, day: Int, lunarMonth: Int, rokuyo: Rokuyo)] = [
            (2012, 4, 21, 3, .sakimake),  // 閏3月。中国は閏4月
            (2017, 6, 24, 5, .taian),  // 閏5月。中国は閏6月
            (2020, 5, 23, 4, .butsumetsu),  // 閏4月
            (2023, 3, 22, 2, .tomobiki),  // 閏2月
            (2025, 7, 25, 6, .shakko),  // 閏6月
            (2028, 6, 23, 5, .taian),  // 閏5月
        ]
        for leap in leapMonthStarts {
            XCTAssertEqual(LunarDate(year: leap.year, month: leap.month, day: leap.day)?.month, leap.lunarMonth, "\(leap)")
            XCTAssertEqual(LunarDate(year: leap.year, month: leap.month, day: leap.day)?.day, 1, "\(leap)")
            XCTAssertEqual(Rokuyo(year: leap.year, month: leap.month, day: leap.day), leap.rokuyo, "\(leap)")
        }
    }

    func testLeapEleventhMonthIn2033() {
        // 2033年問題。日本カレンダー暦文化振興協会の推奨どおり閏11月とする
        XCTAssertEqual(LunarDate(year: 2033, month: 11, day: 22).map { [$0.month, $0.day] }, [11, 1])
        XCTAssertEqual(LunarDate(year: 2033, month: 12, day: 21).map { [$0.month, $0.day] }, [11, 30])
        XCTAssertEqual(LunarDate(year: 2033, month: 12, day: 22).map { [$0.month, $0.day] }, [11, 1])
        XCTAssertEqual(LunarDate(year: 2034, month: 1, day: 20).map { [$0.month, $0.day] }, [12, 1])
        XCTAssertEqual(Rokuyo(year: 2033, month: 12, day: 22), .taian)
    }

    func testNewMoonNearMidnightInJapanTime() {
        // 朔が日本時間0時の前後にある月。中国時間（1時間遅れ）で判定すると日がずれる
        let cases: [(year: Int, month: Int, day: Int, note: String)] = [
            (2005, 12, 2, "0時01分"),
            (2012, 6, 20, "0時02分"),
            (2017, 2, 26, "23時58分"),
            (2023, 5, 20, "0時53分"),
            (2026, 10, 11, "0時50分"),
        ]
        for item in cases {
            XCTAssertEqual(LunarDate(year: item.year, month: item.month, day: item.day)?.day, 1, item.note)
            XCTAssertTrue(MoonPhase(year: item.year, month: item.month, day: item.day)?.isNewMoon == true, item.note)
        }
        XCTAssertEqual(LunarDate(year: 2026, month: 10, day: 10).map { [$0.month, $0.day] }, [8, 30])
    }

    func testRokuyoFollowsRuleThroughWholeRange() {
        // 1600〜2100年の全日で、月の長さが29日か30日であること、月の番号が順に進むこと、
        // 六曜が月初の決まりと並びどおりであることを確かめる
        var previous: LunarDate?
        for year in AppConfig.yearRange {
            for month in 1...12 {
                for day in 1...daysIn(year: year, month: month) {
                    guard let lunar = LunarDate(year: year, month: month, day: day) else {
                        XCTFail("\(year)-\(month)-\(day)")
                        return
                    }
                    XCTAssertEqual(
                        Rokuyo(year: year, month: month, day: day),
                        Self.expectedRokuyo(lunarMonth: lunar.month, lunarDay: lunar.day)
                    )
                    if let previous {
                        if lunar.day == 1 {
                            XCTAssertTrue([29, 30].contains(previous.day), "\(year)-\(month)-\(day)")
                            // 閏月は同じ番号が続く
                            XCTAssertTrue(
                                [previous.month, previous.month % 12 + 1].contains(lunar.month),
                                "\(year)-\(month)-\(day)"
                            )
                        } else {
                            XCTAssertEqual(lunar.day, previous.day + 1, "\(year)-\(month)-\(day)")
                        }
                    }
                    previous = lunar
                }
            }
        }
    }

    private func daysIn(year: Int, month: Int) -> Int {
        let isLeapYear = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        return [31, isLeapYear ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
    }

    // MARK: - 月の満ち欠け

    func testSpokenDescriptionAroundFullMoons() {
        // 満月と読むのは望を含む日だけ。前日と翌日は満ち欠けの向きで伝える
        let cases: [(month: Int, day: Int, text: String)] = [
            (1, 2, "輝面率98パーセント、満ちていく月"),
            (1, 3, "満月、輝面率100パーセント"),
            (1, 4, "輝面率99パーセント、欠けていく月"),
            (10, 25, "輝面率99パーセント、満ちていく月"),
            (10, 26, "満月、輝面率100パーセント"),
            (10, 27, "輝面率99パーセント、欠けていく月"),
            (12, 23, "輝面率99パーセント、満ちていく月"),
            (12, 24, "満月、輝面率100パーセント"),
            (12, 25, "輝面率98パーセント、欠けていく月"),
        ]
        for item in cases {
            XCTAssertEqual(MoonPhase(year: 2026, month: item.month, day: item.day)?.spokenDescription, item.text, "\(item)")
        }
        // 0%は新月の日だけ。前日は丸めると0%になるが1%にする
        XCTAssertEqual(MoonPhase(year: 2026, month: 10, day: 11)?.spokenDescription, "新月、輝面率0パーセント")
        XCTAssertEqual(MoonPhase(year: 2026, month: 10, day: 10)?.spokenDescription, "輝面率1パーセント、欠けていく月")
    }

    func testWaxingAndWaningMatchNAOJNewAndFullMoons2026() {
        // 正午が直近の朔より後なら満ちていく、望より後なら欠けていく
        var events: [(month: Int, day: Int, isNewMoon: Bool)] =
            Self.newMoons2026.map { ($0.month, $0.day, true) } + Self.fullMoons2026.map { ($0.month, $0.day, false) }
        events.sort { ($0.month, $0.day) < ($1.month, $1.day) }
        for month in 1...12 {
            for day in 1...Self.daysInMonth2026[month - 1] {
                guard let moon = MoonPhase(year: 2026, month: month, day: day), !moon.isNewMoon, !moon.isFullMoon else { continue }
                // 1月1日〜2日は前年12月20日の朔の後
                let lastEvent = events.last { ($0.month, $0.day) < (month, day) }
                let isWaxing = lastEvent?.isNewMoon ?? true
                XCTAssertEqual(moon.phasePosition < 0.5, isWaxing, "\(month)/\(day)")
            }
        }
    }

    func testPhasePositionAgreesWithNAOJMoonAge2026() {
        // 国立天文台の正午月齢（東京）と比べる。phasePosition は黄経差から求めた位置で
        // 月齢（朔からの経過日数）とは月の速さの変化の分だけずれるため、1日以内なら一致とみなす
        let synodicMonth = 29.530588853
        for month in 1...12 {
            for (index, age) in Self.naojNoonMoonAges2026[month - 1].enumerated() {
                let day = index + 1
                guard let moon = MoonPhase(year: 2026, month: month, day: day) else {
                    XCTFail("\(month)/\(day)")
                    continue
                }
                var difference = moon.phasePosition * synodicMonth - age
                // 朔をまたいだ前後は周期の端どうしを比べることになるので折り返す
                difference = (difference + synodicMonth / 2).truncatingRemainder(dividingBy: synodicMonth)
                if difference < 0 { difference += synodicMonth }
                difference -= synodicMonth / 2
                XCTAssertLessThan(abs(difference), 1.0, "\(month)/\(day)")
            }
        }
    }

    /// 国立天文台 暦計算室「日の出入り（東京）」の2026年の正午月齢
    private static let naojNoonMoonAges2026: [[Double]] = [
        // 1月
        [
            12.1, 13.1, 14.1, 15.1, 16.1, 17.1, 18.1, 19.1, 20.1, 21.1, 22.1, 23.1, 24.1, 25.1, 26.1, 27.1,
            28.1, 29.1, 0.3, 1.3, 2.3, 3.3, 4.3, 5.3, 6.3, 7.3, 8.3, 9.3, 10.3, 11.3, 12.3,
        ],
        // 2月
        [
            13.3, 14.3, 15.3, 16.3, 17.3, 18.3, 19.3, 20.3, 21.3, 22.3, 23.3, 24.3, 25.3, 26.3, 27.3, 28.3,
            29.3, 0.6, 1.6, 2.6, 3.6, 4.6, 5.6, 6.6, 7.6, 8.6, 9.6, 10.6,
        ],
        // 3月
        [
            11.6, 12.6, 13.6, 14.6, 15.6, 16.6, 17.6, 18.6, 19.6, 20.6, 21.6, 22.6, 23.6, 24.6, 25.6, 26.6,
            27.6, 28.6, 0.1, 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1, 8.1, 9.1, 10.1, 11.1, 12.1,
        ],
        // 4月
        [
            13.1, 14.1, 15.1, 16.1, 17.1, 18.1, 19.1, 20.1, 21.1, 22.1, 23.1, 24.1, 25.1, 26.1, 27.1, 28.1,
            29.1, 0.6, 1.6, 2.6, 3.6, 4.6, 5.6, 6.6, 7.6, 8.6, 9.6, 10.6, 11.6, 12.6,
        ],
        // 5月
        [
            13.6, 14.6, 15.6, 16.6, 17.6, 18.6, 19.6, 20.6, 21.6, 22.6, 23.6, 24.6, 25.6, 26.6, 27.6, 28.6,
            0.3, 1.3, 2.3, 3.3, 4.3, 5.3, 6.3, 7.3, 8.3, 9.3, 10.3, 11.3, 12.3, 13.3, 14.3,
        ],
        // 6月
        [
            15.3, 16.3, 17.3, 18.3, 19.3, 20.3, 21.3, 22.3, 23.3, 24.3, 25.3, 26.3, 27.3, 28.3, 0.0, 1.0,
            2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0,
        ],
        // 7月
        [
            16.0, 17.0, 18.0, 19.0, 20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0, 27.0, 28.0, 29.0, 0.7, 1.7,
            2.7, 3.7, 4.7, 5.7, 6.7, 7.7, 8.7, 9.7, 10.7, 11.7, 12.7, 13.7, 14.7, 15.7, 16.7,
        ],
        // 8月
        [
            17.7, 18.7, 19.7, 20.7, 21.7, 22.7, 23.7, 24.7, 25.7, 26.7, 27.7, 28.7, 0.4, 1.4, 2.4, 3.4,
            4.4, 5.4, 6.4, 7.4, 8.4, 9.4, 10.4, 11.4, 12.4, 13.4, 14.4, 15.4, 16.4, 17.4, 18.4,
        ],
        // 9月
        [
            19.4, 20.4, 21.4, 22.4, 23.4, 24.4, 25.4, 26.4, 27.4, 28.4, 29.4, 1.0, 2.0, 3.0, 4.0, 5.0,
            6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0,
        ],
        // 10月
        [
            20.0, 21.0, 22.0, 23.0, 24.0, 25.0, 26.0, 27.0, 28.0, 29.0, 0.5, 1.5, 2.5, 3.5, 4.5, 5.5,
            6.5, 7.5, 8.5, 9.5, 10.5, 11.5, 12.5, 13.5, 14.5, 15.5, 16.5, 17.5, 18.5, 19.5, 20.5,
        ],
        // 11月
        [
            21.5, 22.5, 23.5, 24.5, 25.5, 26.5, 27.5, 28.5, 29.5, 0.8, 1.8, 2.8, 3.8, 4.8, 5.8, 6.8,
            7.8, 8.8, 9.8, 10.8, 11.8, 12.8, 13.8, 14.8, 15.8, 16.8, 17.8, 18.8, 19.8, 20.8,
        ],
        // 12月
        [
            21.8, 22.8, 23.8, 24.8, 25.8, 26.8, 27.8, 28.8, 0.1, 1.1, 2.1, 3.1, 4.1, 5.1, 6.1, 7.1,
            8.1, 9.1, 10.1, 11.1, 12.1, 13.1, 14.1, 15.1, 16.1, 17.1, 18.1, 19.1, 20.1, 21.1, 22.1,
        ],
    ]

    // MARK: - 範囲の境界

    func testRangeBoundaries() {
        // 1600年元日は旧暦11月16日、2100年大晦日は旧暦12月1日
        XCTAssertEqual(LunarDate(year: 1600, month: 1, day: 1).map { [$0.month, $0.day] }, [11, 16])
        XCTAssertEqual(LunarDate(year: 2100, month: 12, day: 31).map { [$0.month, $0.day] }, [12, 1])
        XCTAssertEqual(Rokuyo(year: 1600, month: 1, day: 1), Self.expectedRokuyo(lunarMonth: 11, lunarDay: 16))
        XCTAssertEqual(Rokuyo(year: 2100, month: 12, day: 31), .shakko)
        XCTAssertNotNil(MoonPhase(year: 1600, month: 1, day: 1))
        XCTAssertNotNil(MoonPhase(year: 2100, month: 12, day: 31))
        // 表の外は出さない。表は1599年12月17日始まりで、2101年1月29日の月は終わりが分からないので使わない
        XCTAssertNil(LunarDate(year: 1599, month: 12, day: 16))
        XCTAssertNotNil(LunarDate(year: 2101, month: 1, day: 28))
        XCTAssertNil(LunarDate(year: 2101, month: 1, day: 29))
        XCTAssertNil(Rokuyo(year: 2101, month: 1, day: 29))
        XCTAssertNil(MoonPhase(year: 2101, month: 1, day: 29))
    }
}
