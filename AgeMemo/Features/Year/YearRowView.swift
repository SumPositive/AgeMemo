// 西暦・和暦・年齢・干支とメモを一行に表示する

import SwiftUI

struct YearRowView: View {
    let row: YearRow
    let age: Int?
    let memo: String?
    let isCurrentYear: Bool
    let isBirthYear: Bool
    /// 年齢指定などで選ばれた行。当年より強い色で示す
    var isSelected: Bool = false
    /// 年齢モードでは年齢を左端に置き、一覧の性格の違いを明確にする
    var showsAgeFirst: Bool = false
    let compact: Bool
    @ScaledMetric(relativeTo: .body) private var preferredFontSize: CGFloat = 17

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

            if isBirthYear || !(memo?.isEmpty ?? true) {
                HStack(spacing: 6) {
                    if isBirthYear {
                        Text("生年")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundStyle(.white)
                            .background(.tint, in: Capsule())
                    }

                    if let memo, !memo.isEmpty {
                        Text(memo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 60)
            }
        }
        .foregroundStyle(rowTextColor)
        .padding(.horizontal, 6)
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
        // 年齢指定の選択行と、自分／名簿の生年行は同じ濃さで示す
        if isSelected || isBirthYear {
            Color.accentColor.opacity(0.30)
        } else if isCurrentYear {
            // 当年は現在位置の目印として薄く残す
            Color.accentColor.opacity(0.14)
        } else {
            Color.clear
        }
    }

    private func primaryLine(scale: CGFloat) -> some View {
        let fontSize = preferredFontSize * scale
        return HStack(spacing: 2) {
            if showsAgeFirst {
                ageColumn(fontSize: fontSize, alignment: .leading)

                Spacer(minLength: 0)

                gregorianColumn(fontSize: fontSize)

                Spacer(minLength: 0)

                eraColumn(fontSize: fontSize)
                    .frame(width: fontSize * 4.7, alignment: .leading)

                Spacer(minLength: 0)

                zodiacColumn(fontSize: fontSize)
            } else {
                gregorianColumn(fontSize: fontSize)

                Spacer(minLength: 0)

                eraColumn(fontSize: fontSize)
                    .frame(width: fontSize * 4.7, alignment: .leading)

                Spacer(minLength: 0)

                zodiacColumn(fontSize: fontSize)

                Spacer(minLength: 0)

                ageColumn(fontSize: fontSize, alignment: .trailing)
            }
        }
    }

    private func gregorianColumn(fontSize: CGFloat) -> some View {
        Text(String(row.gregorian))
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            .frame(width: fontSize * 2.55, alignment: .trailing)
    }

    private func zodiacColumn(fontSize: CGFloat) -> some View {
        Text("\(row.stemBranch.branch.emoji) \(row.stemBranch.branch.kanji)")
            .font(.system(size: fontSize))
            .lineLimit(1)
            .frame(width: fontSize * 2.55, alignment: .leading)
    }

    @ViewBuilder
    private func ageColumn(fontSize: CGFloat, alignment: Alignment) -> some View {
        if let age {
            Text("\(age)歳")
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(age < 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(rowTextColor))
                .lineLimit(1)
                .frame(width: fontSize * 3.6, alignment: alignment)
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
