// 月齢と月相を求める

import Foundation

struct MoonPhase: Sendable {
    /// 朔（新月）からの日数。0が新月、約14.8で満月
    let age: Double

    private static let synodicMonth = 29.530588853

    /// 旧暦の日から求める。旧暦の1日が朔にあたる
    init?(date: Date, calendar: Calendar = .lunisolar) {
        guard let day = calendar.dateComponents([.day], from: date).day else { return nil }
        age = Double(day - 1)
    }

    /// 満ちている割合。新月が0、満月が1
    var illumination: Double {
        let phase = age / Self.synodicMonth
        return (1 - cos(2 * .pi * phase)) / 2
    }

    var illuminationPercent: Int {
        Int((illumination * 100).rounded())
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
}
