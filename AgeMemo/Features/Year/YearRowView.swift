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
    /// 年齢モードでは年齢を左端に置き、一覧の性格の違いを明確にする
    var showsAgeFirst: Bool = false
    /// 干支列を表示する。九星だけONの場合は九星のみを同じ列に出す
    var showsZodiac: Bool = false
    /// 還暦・喜寿などの節目。該当しない年は nil
    var longevity: Longevity?
    /// 前厄・本厄・後厄。性別が未指定なら nil
    var unluckyYear: UnluckyYear?
    /// 入学・卒業の節目。設定がOFFなら nil
    var schoolMilestone: SchoolMilestone?
    /// 九星の本命星。設定がOFFなら nil
    var nineStar: NineStar?
    let compact: Bool
    @ScaledMetric(relativeTo: .body) private var preferredFontSize: CGFloat = 17
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// 列間の最小幅。余った幅は各列間へ均等に配分する
    private let columnSpacing: CGFloat = 8

    /// 特大以上では横に並べきれないので2段へ落とす
    private var stacksNineStar: Bool {
        DynamicTypeSize.accessibility1 <= dynamicTypeSize
    }

    private var hasSecondaryLine: Bool {
        !(memo?.isEmpty ?? true)
            || longevity != nil || unluckyYear != nil || schoolMilestone != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 5) {
            ViewThatFits(in: .horizontal) {
                primaryLine(scale: 1.0)
                primaryLine(scale: 0.9)
                primaryLine(scale: 0.8)
                primaryLine(scale: 0.7)
                primaryLine(scale: 0.6)
                primaryLine(scale: 0.55)
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

                    // 節目は右端にまとめる
                    if let schoolMilestone {
                        Text(schoolMilestone.shortName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    if let longevity {
                        Text(longevity.name)
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .lineLimit(1)
                    }

                    if let unluckyYear {
                        Text(unluckyYear.name)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
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

    /// ダークモードの純白は一覧が明滅して見えるため、少し落ち着かせる
    private var rowTextColor: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.86, alpha: 1)
                : UIColor.label
        })
    }

    private var rowBackground: Color {
        // 移動先は緑系にして、自分／名簿の生年行と区別する
        if isSelected {
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
        let fontSize = preferredFontSize * scale
        // 収まる文字倍率を決めた後、余った幅をSpacerで左右端と各列間へ均等に配る
        return HStack(spacing: 0) {
            columnGap
            if showsAgeFirst {
                ageColumn(fontSize: fontSize)
                columnGap
                gregorianColumn(fontSize: fontSize)
                columnGap
                eraColumn(fontSize: fontSize)
                    .frame(width: fontSize * 4.1, alignment: .leading)
                if showsZodiac || nineStar != nil {
                    columnGap
                    zodiacColumn(fontSize: fontSize)
                }
            } else {
                gregorianColumn(fontSize: fontSize)
                columnGap
                eraColumn(fontSize: fontSize)
                    .frame(width: fontSize * 4.1, alignment: .leading)
                if showsZodiac || nineStar != nil {
                    columnGap
                    zodiacColumn(fontSize: fontSize)
                }
                columnGap
                ageColumn(fontSize: fontSize)
            }
            columnGap
        }
        .frame(maxWidth: .infinity)
    }

    /// 複数のSpacerは余白を同じ幅で分け合う
    private var columnGap: some View {
        Spacer(minLength: columnSpacing)
    }

    private func gregorianColumn(fontSize: CGFloat) -> some View {
        Text(String(row.gregorian))
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .frame(width: fontSize * 2.55, alignment: .trailing)
    }

    @ViewBuilder
    private func zodiacColumn(fontSize: CGFloat) -> some View {
        if showsZodiac, let nineStar {
            // 文字が大きいときだけ2段にする。ViewThatFits に任せると
            // 列幅の取り合いで行全体が縮み、文字サイズの差が消えてしまう
            Group {
                if stacksNineStar {
                    VStack(alignment: .leading, spacing: 0) {
                        zodiacText(size: fontSize * 0.82)
                        nineStarText(nineStar, size: fontSize * 0.70)
                    }
                } else {
                    HStack(spacing: 3) {
                        zodiacText(size: fontSize)
                        nineStarText(nineStar, size: fontSize * 0.72)
                    }
                }
            }
            // 2段は中身が幅を決める。固定幅にすると余りが右に溜まり、
            // 隣の年齢との間だけが空いて見える
            .fixedSize(horizontal: stacksNineStar, vertical: false)
            .frame(
                width: stacksNineStar ? nil : fontSize * 5.5,
                height: fontSize * 1.25,
                alignment: .leading
            )
        } else if showsZodiac {
            zodiacText(size: fontSize)
                .frame(width: fontSize * 2.55, alignment: .leading)
        } else if let nineStar {
            nineStarText(nineStar, size: fontSize * 0.72)
                .frame(width: fontSize * 3.2, alignment: .leading)
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
            Text("\(age)歳")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(age < 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(rowTextColor))
                .lineLimit(1)
                .frame(width: fontSize * 3.6, alignment: .trailing)
        } else {
            // 年齢未設定時も列配置を保つ
            Color.clear
                .frame(width: fontSize * 3.6)
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
