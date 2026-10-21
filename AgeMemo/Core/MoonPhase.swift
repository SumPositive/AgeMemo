// 月齢と月相を求める

import Foundation

struct MoonPhase: Sendable {
    /// 月と太陽の黄経の差（度）。0が新月、180が満月
    let elongation: Double
    /// 望（満月の瞬間）を含む日か。一般的なカレンダーの満月の日と同じ
    let isFullMoon: Bool

    private static let synodicMonth = 29.530588853

    /// その日の日本時間の正午で求める。満月の日は表から引く
    init?(year: Int, month: Int, day: Int) {
        guard let lunar = LunarDate(year: year, month: month, day: day) else { return nil }
        isFullMoon = lunar.isFullMoon
        // 1970年1月1日0時（世界時）のユリウス日に、日本時間の正午（世界時3時）を足す
        let julianDay = Double(LunarDate.dayNumber(year: year, month: month, day: day)) + 2_440_587.5 + 3.0 / 24
        elongation = Self.elongation(julianDay: julianDay)
    }

    /// 朔（新月）からの日数。0が新月、約14.8で満月
    var age: Double {
        elongation / 360 * Self.synodicMonth
    }

    /// 満ちている割合。新月が0、満月が1
    var illumination: Double {
        (1 - cos(elongation * .pi / 180)) / 2
    }

    /// 100%は満月の日だけにし、前後の日は丸めで100%にならないよう99%で止める
    var illuminationPercent: Int {
        isFullMoon ? 100 : min(Int((illumination * 100).rounded()), 99)
    }

    /// 月相を8つに分けたときの絵柄
    var symbolName: String {
        switch age {
        case ..<1.85: "moonphase.new.moon"
        case ..<5.54: "moonphase.waxing.crescent"
        case ..<9.23: "moonphase.first.quarter"
        case ..<12.92: "moonphase.waxing.gibbous"
        case ..<16.61: "moonphase.full.moon"
        case ..<20.30: "moonphase.waning.gibbous"
        case ..<23.99: "moonphase.last.quarter"
        case ..<27.68: "moonphase.waning.crescent"
        default: "moonphase.new.moon"
        }
    }

    var name: String {
        switch age {
        case ..<1.85: "新月"
        case ..<5.54: "三日月"
        case ..<9.23: "上弦"
        case ..<12.92: "十三夜"
        case ..<16.61: "満月"
        case ..<20.30: "寝待月"
        case ..<23.99: "下弦"
        case ..<27.68: "有明月"
        default: "新月"
        }
    }

    /// 月と太陽の黄経の差を、天文計算の主要な項だけで求める（Meeus『天文アルゴリズム』47章）。
    /// 誤差は0.1度未満で、輝面率にすると1%未満
    private static func elongation(julianDay: Double) -> Double {
        let t = (julianDay - 2_451_545) / 36_525
        // 太陽の黄経
        let sunMeanLongitude = 280.46646 + 36_000.76983 * t
        let sunAnomaly = 357.52911 + 35_999.05029 * t
        let sunLongitude = sunMeanLongitude
            + (1.914602 - 0.004817 * t) * sinDegrees(sunAnomaly)
            + 0.019993 * sinDegrees(2 * sunAnomaly)
        // 月の黄経
        let moonMeanLongitude = 218.3164477 + 481_267.88123421 * t
        let d = 297.8501921 + 445_267.1114034 * t
        let moonAnomaly = 134.9633964 + 477_198.8675055 * t
        let f = 93.2720950 + 483_202.0175233 * t
        let correction = moonLongitudeTerms.reduce(0.0) { sum, term in
            sum + term.coefficient * sinDegrees(
                term.d * d + term.sunAnomaly * sunAnomaly + term.moonAnomaly * moonAnomaly + term.f * f
            )
        }
        let difference = (moonMeanLongitude + correction - sunLongitude).truncatingRemainder(dividingBy: 360)
        return difference < 0 ? difference + 360 : difference
    }

    private static func sinDegrees(_ degrees: Double) -> Double {
        sin(degrees * .pi / 180)
    }

    /// 月の黄経の補正項。係数（度）と、D・太陽の平均近点角・月の平均近点角・F に掛ける数
    private static let moonLongitudeTerms: [(coefficient: Double, d: Double, sunAnomaly: Double, moonAnomaly: Double, f: Double)] = [
        (6.288774, 0, 0, 1, 0), (1.274027, 2, 0, -1, 0), (0.658314, 2, 0, 0, 0),
        (0.213618, 0, 0, 2, 0), (-0.185116, 0, 1, 0, 0), (-0.114332, 0, 0, 0, 2),
        (0.058793, 2, 0, -2, 0), (0.057066, 2, -1, -1, 0), (0.053322, 2, 0, 1, 0),
        (0.045758, 2, -1, 0, 0), (-0.040923, 0, 1, -1, 0), (-0.034720, 1, 0, 0, 0),
        (-0.030383, 0, 1, 1, 0), (0.015327, 2, 0, 0, -2), (-0.012528, 0, 0, 1, 2),
        (0.010980, 0, 0, 1, -2), (0.010675, 4, 0, -1, 0), (0.010034, 0, 0, 3, 0),
        (0.008548, 4, 0, -2, 0), (-0.007888, 2, 1, -1, 0), (-0.006766, 2, 1, 0, 0),
        (-0.005163, 1, 0, -1, 0),
    ]
}
