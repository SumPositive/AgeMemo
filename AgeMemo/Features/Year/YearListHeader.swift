// 一覧の先頭に固定する列見出し。並び順の切り替えも兼ねる

import SwiftUI

/// 一覧の列見出し。西暦・和暦・年齢の位置を示し、矢印で並び順を表す。
///
/// 3列はいずれも西暦年の単調な関数（和暦は西暦から導出、年齢は西暦との差）
/// なので、並び順は1つしかない。どの列をタップしても同じ並び順が反転し、
/// 3列の矢印は連動して切り替わる。
///
/// 「生まれ年」一覧の年齢だけは西暦と逆向きに増えるため、矢印も他の2列と
/// 反対を向く。この向きの違いこそが一覧の性格を表すので、隠さず常に見せる。
struct YearListHeader: View {
    let sortOrder: YearSortOrder
    /// 年齢列が西暦と逆向きに増えるか。「生まれ年」一覧では true
    let invertsAgeDirection: Bool
    /// 年齢列の見出し。記念日を選んでいるときは「周年」にする
    let showsAnniversaryUnit: Bool
    /// 干支列を出しているか。行と同じ列構成にするために要る
    let showsZodiac: Bool
    /// 九星を出しているか。干支と積むと列幅の基準が変わる
    let showsNineStar: Bool
    /// 学齢・賀寿・厄年の列を確保しているか
    let reservesBadgeColumn: Bool
    let compact: Bool
    let toggle: () -> Void

    /// 列幅は行と同じ基準サイズから決める。見出しの文字だけを小さくする
    @ScaledMetric(relativeTo: .body) private var rowFontSize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) private var labelFontSize: CGFloat = 12

    /// 年齢列の矢印。西暦と逆向きに増える一覧では反対を向く
    private var ageOrder: YearSortOrder {
        invertsAgeDirection ? sortOrder.toggled : sortOrder
    }

    private var ageTitle: LocalizedStringKey {
        showsAnniversaryUnit ? "周年" : "年齢"
    }

    private var showsZodiacColumn: Bool {
        showsZodiac || showsNineStar
    }

    var body: some View {
        // 行と同じ列幅・列間・端余白で並べ、見出しが中身の真上に来るようにする。
        // 行は ViewThatFits で縮むことがあるが、見出しは基準サイズのまま置く
        HStack(spacing: 0) {
            Spacer(minLength: YearColumnMetrics.edgeInset)

            headerLabel("西暦", order: sortOrder)
                .frame(width: rowFontSize * YearColumnMetrics.gregorianWidthRatio, alignment: .trailing)
            Spacer(minLength: YearColumnMetrics.columnSpacing)
            headerLabel("和暦", order: sortOrder)
                .frame(width: rowFontSize * YearColumnMetrics.eraWidthRatio, alignment: .leading)
            Spacer(minLength: YearColumnMetrics.columnSpacing)
            headerLabel(ageTitle, order: ageOrder)
                .frame(minWidth: rowFontSize * YearColumnMetrics.ageMinWidthRatio, alignment: .trailing)

            if showsZodiacColumn {
                Spacer(minLength: YearColumnMetrics.columnSpacing)
                // 干支・九星は年そのものの属性で並び順を持たないため、矢印は付けない
                plainLabel(showsZodiac ? "干支" : "九星")
                    .frame(
                        width: YearColumnMetrics.zodiacWidth(
                            fontSize: rowFontSize,
                            showsNineStar: showsZodiac && showsNineStar
                        ),
                        alignment: .leading
                    )
            }

            if reservesBadgeColumn {
                Spacer(minLength: YearColumnMetrics.columnSpacing)
                plainLabel("節目")
                    .frame(width: YearColumnMetrics.badgeWidth(fontSize: rowFontSize), alignment: .leading)
            }

            Spacer(minLength: YearColumnMetrics.edgeInset)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 4 : 6)
        .contentShape(Rectangle())
        .onTapGesture(perform: toggle)
        // 3列は同じ並び順なので、まとめて1つの操作として読み上げる
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sortOrder == .ascending ? Text("西暦の小さい順") : Text("西暦の大きい順"))
        .accessibilityHint("タップすると並び順を切り替えます")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("list.header")
    }

    /// 並び順を持つ列の見出し。名前と矢印を添える
    private func headerLabel(_ title: LocalizedStringKey, order: YearSortOrder) -> some View {
        HStack(spacing: 1) {
            Text(title)
            Image(systemName: order == .ascending ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .font(.system(size: labelFontSize * 0.62))
        }
        .font(.system(size: labelFontSize, weight: .semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// 並び順に関わらない列の見出し
    private func plainLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: labelFontSize, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}
