// 一覧に表示する年固有の不変データを表す

import Foundation

struct EraSpan: Hashable, Sendable {
    let eraIdentifier: Int
    let eraName: String
    let eraYear: Int
    /// 改元日。明治より前は改元日が翌年1月にあたり、行の西暦年と違うことがある
    let startYear: Int
    let startMonth: Int
    let startDay: Int

    var isGanNen: Bool { eraYear == 1 }

    var displayText: String {
        "\(eraName)\(isGanNen ? "元" : String(eraYear))年"
    }
}

struct YearRow: Identifiable, Hashable, Sendable {
    let id: Int
    let gregorian: Int
    let eraSpans: [EraSpan]
    let stemBranch: StemBranch

    var eraDisplayText: String {
        eraSpans.map(\.displayText).joined(separator: "/")
    }
}

struct EraChoice: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let firstGregorianYear: Int
}
