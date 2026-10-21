// 旧暦・六曜・月の満ち欠けの回帰テスト
// 期待値は国立天文台の公表値（暦要項の朔弦望）、NASA JPL の DE440 による天文計算、一般的なカレンダーの六曜の決まりから取る

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

    func testElongationAgreesWithDE440() {
        // 月と太陽の黄経差を、NASA JPL の DE440 から求めた値（日本時間の正午・視位置）と代表日で比べる回帰テスト。
        // 1600〜2100年の全日の保証は Scripts/verify_moon_phase.py が受け持ち、ここは式の変更による劣化を拾う
        for reference in Self.de440Noon {
            guard let moon = MoonPhase(year: reference.year, month: reference.month, day: reference.day) else {
                XCTFail("\(reference)")
                continue
            }
            var difference = (moon.elongation - reference.elongation).truncatingRemainder(dividingBy: 360)
            // 0度と360度をまたぐ差は折り返す
            if 180 < difference { difference -= 360 }
            if difference < -180 { difference += 360 }
            XCTAssertLessThan(abs(difference), 0.1, "\(reference)")
            // 輝面率は1%未満の差に収まる（実測の最大は0.23ポイント）
            XCTAssertLessThan(abs(moon.illumination - reference.illumination), 0.01, "\(reference)")
        }
    }

    /// DE440（skyfield）で求めた日本時間正午の黄経差（度）と輝面率。
    /// 10年ごとの元日、2026年の15日おき、全期間の走査で誤差が最大だった日（黄経差は1999-11-25、輝面率は1600-12-01）を含む
    private static let de440Noon: [(year: Int, month: Int, day: Int, elongation: Double, illumination: Double)] = [
        (1600, 1, 1, 186.3216, 0.99686),
        (1600, 2, 5, 245.0293, 0.71138),
        (1600, 12, 1, 309.7726, 0.18228),
        (1610, 1, 1, 68.0365, 0.31467),
        (1620, 1, 1, 319.3944, 0.12156),
        (1630, 1, 1, 207.0146, 0.94477),
        (1640, 1, 1, 88.9103, 0.49184),
        (1650, 1, 1, 341.3999, 0.02664),
        (1660, 1, 1, 217.9655, 0.89322),
        (1670, 1, 1, 119.6192, 0.74801),
        (1680, 1, 1, 350.1642, 0.00918),
        (1690, 1, 1, 255.1547, 0.62938),
        (1700, 1, 1, 120.8822, 0.75685),
        (1710, 1, 1, 13.0775, 0.01379),
        (1720, 1, 1, 245.7642, 0.70618),
        (1730, 1, 1, 144.4778, 0.90610),
        (1740, 1, 1, 24.5567, 0.04549),
        (1750, 1, 1, 272.9961, 0.47539),
        (1760, 1, 1, 158.8428, 0.96640),
        (1770, 1, 1, 43.6024, 0.13987),
        (1780, 1, 1, 296.7211, 0.27643),
        (1790, 1, 1, 177.8161, 0.99846),
        (1800, 1, 1, 69.4802, 0.32620),
        (1810, 1, 1, 297.1849, 0.27269),
        (1820, 1, 1, 187.3852, 0.99408),
        (1830, 1, 1, 77.1347, 0.38982),
        (1840, 1, 1, 318.2112, 0.12926),
        (1850, 1, 1, 215.8453, 0.90572),
        (1860, 1, 1, 86.3921, 0.46993),
        (1870, 1, 1, 348.9270, 0.00985),
        (1880, 1, 1, 219.1671, 0.88770),
        (1890, 1, 1, 124.0773, 0.78037),
        (1900, 1, 1, 353.9352, 0.00294),
        (1910, 1, 1, 243.1996, 0.72565),
        (1920, 1, 1, 114.4510, 0.70785),
        (1930, 1, 1, 12.3626, 0.01337),
        (1940, 1, 1, 255.9014, 0.62290),
        (1945, 4, 7, 286.1741, 0.36199),
        (1950, 1, 1, 142.8116, 0.89789),
        (1960, 1, 1, 32.3795, 0.07891),
        (1963, 11, 2, 187.8055, 0.99406),
        (1970, 1, 1, 271.9869, 0.48406),
        (1980, 1, 1, 164.9658, 0.98137),
        (1981, 11, 14, 211.1276, 0.92790),
        (1989, 4, 1, 291.0706, 0.32159),
        (1990, 1, 1, 47.7984, 0.16486),
        (1999, 11, 25, 206.0572, 0.94879),
        (2000, 1, 1, 298.8182, 0.26108),
        (2007, 10, 27, 193.2287, 0.98510),
        (2008, 11, 15, 206.3230, 0.94731),
        (2010, 1, 1, 184.5461, 0.99842),
        (2020, 1, 1, 67.4896, 0.31042),
        (2026, 1, 1, 147.8943, 0.92221),
        (2026, 1, 16, 329.5993, 0.07073),
        (2026, 1, 31, 156.0371, 0.95592),
        (2026, 2, 15, 331.8553, 0.06024),
        (2026, 3, 2, 163.0527, 0.97825),
        (2026, 3, 17, 335.5422, 0.04514),
        (2026, 4, 1, 168.6828, 0.99005),
        (2026, 4, 16, 341.4824, 0.02649),
        (2026, 5, 1, 173.2918, 0.99524),
        (2026, 5, 16, 349.9415, 0.00940),
        (2026, 5, 31, 177.3775, 0.99760),
        (2026, 6, 15, 0.0581, 0.00167),
        (2026, 6, 30, 181.3957, 0.99866),
        (2026, 7, 15, 10.0599, 0.00815),
        (2026, 7, 30, 185.8341, 0.99725),
        (2026, 8, 14, 18.4481, 0.02586),
        (2026, 8, 29, 191.2691, 0.99024),
        (2026, 9, 13, 24.6849, 0.04686),
        (2026, 9, 28, 198.1856, 0.97390),
        (2026, 10, 13, 28.9138, 0.06430),
        (2026, 10, 28, 206.5001, 0.94602),
        (2026, 11, 12, 31.6029, 0.07582),
        (2026, 11, 27, 215.2353, 0.90808),
        (2026, 12, 12, 33.4805, 0.08374),
        (2026, 12, 27, 223.0829, 0.86579),
        (2030, 1, 1, 319.5176, 0.12055),
        (2040, 1, 1, 197.3589, 0.97638),
        (2050, 1, 1, 99.4840, 0.58345),
        (2060, 1, 1, 328.4076, 0.07475),
        (2061, 5, 14, 287.6792, 0.34958),
        (2070, 1, 1, 233.3669, 0.79839),
        (2080, 1, 1, 99.3380, 0.58234),
        (2090, 1, 1, 3.3019, 0.00268),
        (2100, 1, 1, 238.4320, 0.76268),
        (2100, 12, 31, 1.7260, 0.00136),
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
