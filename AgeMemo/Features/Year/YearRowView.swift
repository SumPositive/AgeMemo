// 西暦・和暦・年齢・干支とメモを一行に表示する

import SwiftUI

struct YearRowView: View {
    let row: YearRow
    let age: Int?
    let memo: String?
    let isCurrentYear: Bool
    let isBirthYear: Bool
    /// シートから移動した行。背景色で移動先を示す
    var isSelected: Bool = false
    /// 一覧でタップした行。青系・緑系と区別できる色で示す
    var isTapped: Bool = false
    /// 年齢モードでは年齢を左端に置き、一覧の性格の違いを明確にする
    var showsAgeFirst: Bool = false
    /// 干支列を表示する。九星だけONの場合は九星のみを同じ列に出す
    var showsZodiac: Bool = false
    /// 還暦・喜寿などの節目。該当しない年は nil
    var longevity: Longevity?
    /// 前厄・本厄・後厄。性別が未指定なら nil
    var unluckyYear: UnluckyYear?
    /// 小学校1年から大学4年までの学年。設定がOFFなら nil
    var schoolMilestone: SchoolMilestone?
    /// 九星の本命星。設定がOFFなら nil
    var nineStar: NineStar?
    /// 学齢・賀寿・厄年のいずれかが設定でONか。
    /// ONの間は該当しない年でも列幅を確保し、行ごとに列位置がずれないようにする
    var reservesBadgeColumn: Bool = false
    let compact: Bool
    @ScaledMetric(relativeTo: .body) private var preferredFontSize: CGFloat = 17

    /// 基本3列（年齢・西暦・和暦）の列間。常にこの幅で詰めて並べる
    private let baseColumnSpacing: CGFloat = 10
    /// 行の左右端に空ける幅
    private let edgeInset: CGFloat = 12

    private var hasMemo: Bool {
        !(memo?.isEmpty ?? true)
    }

    /// 2行目はメモのためだけに使う
    private var hasSecondaryLine: Bool { hasMemo }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 5) {
            // 補助表示は固定幅の列にしたので、行ごとに形が変わらない。
            // 倍率だけを ViewThatFits で決める
            ViewThatFits(in: .horizontal) {
                ForEach(primaryScales, id: \.self) { scale in
                    primaryLine(scale: scale)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasSecondaryLine {
                HStack(spacing: 6) {
                    if let memo, !memo.isEmpty {
                        Text(memo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                }
                .padding(.horizontal, 6)
                .padding(.leading, 60)
            }
        }
        .foregroundStyle(rowTextColor)
        .padding(.vertical, compact ? 6 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// 収まる倍率を上から順に試す
    private var primaryScales: [CGFloat] { [1.0, 0.9, 0.8, 0.7, 0.6, 0.55] }

    /// ダークモードの純白は一覧が明滅して見えるため、少し落ち着かせる
    private var rowTextColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.86, alpha: 1)
                : UIColor.label
        })
    }

    private var rowBackground: Color {
        // タップ行はオレンジ系にして、当年・生年・移動先と区別する
        if isTapped {
            Color(uiColor: .systemOrange).opacity(0.30)
        } else if isSelected {
            // 移動先は緑系にして、自分／名簿の生年行と区別する
            Color(uiColor: .systemGreen).opacity(0.30)
        } else if isBirthYear {
            Color.accentColor.opacity(0.30)
        } else if isCurrentYear {
            // 当年も生年と同じ濃さにしてダークモードでの視認性を保つ
            Color.accentColor.opacity(0.30)
        } else {
            Color.clear
        }
    }

    private func primaryLine(scale: CGFloat) -> some View {
        // 基本3列は設定した文字サイズのまま出す。縮めると行ごとに大きさが
        // 変わって読みにくいので、狭いときに縮むのは補助項目だけにする
        let baseFontSize = preferredFontSize
        let auxiliaryFontSize = preferredFontSize * scale

        // 補助列は常に縦積みで最小幅なので、すべての余白を可変にして
        // 均等に配れる。3列なら4か所、5列なら6か所へ同じ幅で分かれる
        return HStack(spacing: 0) {
            Spacer(minLength: edgeInset)

            baseColumn(at: 0, fontSize: baseFontSize)
            Spacer(minLength: baseColumnSpacing)
            baseColumn(at: 1, fontSize: baseFontSize)
            Spacer(minLength: baseColumnSpacing)
            baseColumn(at: 2, fontSize: baseFontSize)

            if showsZodiac || nineStar != nil {
                Spacer(minLength: baseColumnSpacing)
                zodiacColumn(fontSize: auxiliaryFontSize)
            }

            if reservesBadgeColumn {
                Spacer(minLength: baseColumnSpacing)
                badgeColumn(fontSize: auxiliaryFontSize)
            }

            Spacer(minLength: edgeInset)
        }
        .frame(maxWidth: .infinity)
    }

    /// 基本3列の index 番目。年齢一覧だけ年齢が先頭に来る
    @ViewBuilder
    private func baseColumn(at index: Int, fontSize: CGFloat) -> some View {
        let order: [BaseColumnKind] = showsAgeFirst ? [.age, .gregorian, .era] : [.gregorian, .era, .age]
        switch order[index] {
        case .age:
            ageColumn(fontSize: fontSize)
        case .gregorian:
            gregorianColumn(fontSize: fontSize)
        case .era:
            eraColumn(fontSize: fontSize)
                .frame(width: fontSize * 4.1, alignment: .leading)
        }
    }

    private enum BaseColumnKind {
        case age, gregorian, era
    }

    /// 学齢・賀寿・厄年をまとめて出す
    @ViewBuilder
    private func badgeGroup(font: Font) -> some View {
        if let schoolMilestone {
            Text(schoolMilestone.shortName)
                .font(font)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }

        if let longevity {
            Text(longevity.name)
                .font(font)
                .foregroundStyle(.tint)
                .lineLimit(1)
        }

        if let unluckyYear {
            Text(unluckyYear.name)
                .font(font)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    /// 学齢・賀寿・厄年の列。一定幅を保ち、該当しない年は空のまま場所だけ取る
    private func badgeColumn(fontSize: CGFloat) -> some View {
        // 常に縦積み。幅は最長の「大還暦」（3文字）が収まる分で固定し、
        // 該当の有無や文字数で列位置がずれないようにする
        let badgeFontSize = fontSize * 0.66
        return VStack(alignment: .leading, spacing: 0) {
            badgeGroup(font: .system(size: badgeFontSize))
        }
        .lineLimit(1)
        .frame(width: badgeFontSize * 3, alignment: .leading)
    }

    private func gregorianColumn(fontSize: CGFloat) -> some View {
        Text(String(row.gregorian))
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .frame(width: fontSize * 2.55, alignment: .trailing)
    }

    @ViewBuilder
    private func zodiacColumn(fontSize: CGFloat) -> some View {
        // 干支と九星も常に縦積み。幅は九星の「一白水星」（4文字）に合わせて
        // 固定し、行ごとに列位置がずれないようにする
        if showsZodiac, let nineStar {
            let nineStarFontSize = fontSize * 0.70
            VStack(alignment: .leading, spacing: 0) {
                zodiacText(size: fontSize * 0.82)
                nineStarText(nineStar, size: nineStarFontSize)
            }
            .frame(width: nineStarFontSize * 4, alignment: .leading)
        } else if showsZodiac {
            // 絵文字＋漢字1文字ぶん
            zodiacText(size: fontSize)
                .frame(width: fontSize * 2.6, alignment: .leading)
        } else if let nineStar {
            let nineStarFontSize = fontSize * 0.72
            nineStarText(nineStar, size: nineStarFontSize)
                .frame(width: nineStarFontSize * 4, alignment: .leading)
        }
    }

    private func zodiacText(size: CGFloat) -> some View {
        Text("\(row.stemBranch.branch.emoji) \(row.stemBranch.branch.kanji)")
            .font(.system(size: size))
            .lineLimit(1)
    }

    private func nineStarText(_ nineStar: NineStar, size: CGFloat) -> some View {
        Text(nineStar.name)
            .font(.system(size: size))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    @ViewBuilder
    private func ageColumn(fontSize: CGFloat) -> some View {
        if let age {
            let ageText = Text("\(age)歳")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(age < 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(rowTextColor))
                .lineLimit(1)

            if showsAgeFirst {
                // 年齢一覧は年齢列の従来幅を維持する
                ageText
                    .frame(width: fontSize * 3.6, alignment: .trailing)
            } else {
                // 自分／名簿は「99歳」の幅を原則とし、必要な行だけ広げる
                ageText
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(minWidth: fontSize * 2.3, alignment: .trailing)
            }
        } else {
            // 年齢未設定時も列配置を保つ
            Color.clear
                .frame(width: fontSize * (showsAgeFirst ? 3.6 : 2.3))
        }
    }

    private func eraColumn(fontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(row.eraSpans.enumerated()), id: \.offset) { _, span in
                Text(span.displayText)
                    .font(.system(size: fontSize))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }
}
