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
    /// 列の置き方。行と同じ値を受け取ることで、見出しが必ず中身の真上に来る
    let layout: YearColumnMetrics.Layout
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

    var body: some View {
        // 列の幅・列間・構成はすべて layout が決めている。
        // 見出しは行と同じ値でそのまま並べるだけ
        let fontSize = layout.fontSize(base: rowFontSize)
        let columns = layout.columns
        let spacing = layout.columnSpacing
        // 見出しの文字も列と同じ率で縮める。列だけ縮めると、年齢列のように
        // 自然幅で場所を取る見出しが枠を押し広げてしまう
        let labelSize = labelFontSize * layout.scale

        return HStack(spacing: 0) {
            Spacer(minLength: YearColumnMetrics.edgeInset)

            headerLabel("西暦", order: sortOrder, labelSize: labelSize)
                .frame(width: fontSize * YearColumnMetrics.gregorianWidthRatio, alignment: .trailing)
            columnGap(spacing)
            headerLabel("和暦", order: sortOrder, labelSize: labelSize)
                .frame(width: fontSize * YearColumnMetrics.eraWidthRatio, alignment: .leading)
            columnGap(spacing)
            headerLabel(ageTitle, order: ageOrder, labelSize: labelSize)
                // 年齢列だけは下限幅しか決めていないため、他の固定幅列に押されると
                // minimumScaleFactor が働いて見出しだけが縮む。行と同じく
                // 自然な幅を先に確保して、押し潰されないようにする
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: fontSize * YearColumnMetrics.ageMinWidthRatio, alignment: .trailing)

            if columns.showsZodiacColumn {
                columnGap(spacing)
                // 干支・九星は年そのものの属性で並び順を持たないため、矢印は付けない
                plainLabel(columns.showsZodiac ? "干支" : "九星", labelSize: labelSize)
                    .frame(
                        width: YearColumnMetrics.zodiacWidth(
                            fontSize: fontSize,
                            showsNineStar: columns.stacksNineStar
                        ),
                        alignment: .leading
                    )
            }

            if columns.reservesBadgeColumn {
                columnGap(spacing)
                plainLabel("節目", labelSize: labelSize)
                    .frame(width: YearColumnMetrics.badgeWidth(fontSize: fontSize), alignment: .leading)
            }

            Spacer(minLength: YearColumnMetrics.edgeInset)
        }
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

    /// 列と列の間。行と同じ確定幅を置くので、見出しが中身の真上から動かない
    private func columnGap(_ width: CGFloat) -> some View {
        Color.clear.frame(width: width, height: 0)
    }

    /// 並び順を持つ列の見出し。名前と矢印を添える
    private func headerLabel(_ title: LocalizedStringKey, order: YearSortOrder, labelSize labelFontSize: CGFloat) -> some View {
        HStack(spacing: 1) {
            Text(title)
            Image(systemName: sortArrowSymbol(order))
                .font(.system(size: labelFontSize * 0.62))
                // 中空は輪郭線だけになり塗りより弱く見えるため、
                // 反転中の矢印は少し濃くして塗りと存在感をそろえる
                .foregroundStyle(sortOrder == YearSortOrder.default ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.primary))
        }
        .font(.system(size: labelFontSize, weight: .semibold))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }

    /// 並び順の矢印。向きで昇降順を、塗りつぶしの有無で既定かどうかを示す。
    ///
    /// 既定の並びなら中塗り（▲▼）、反転しているときは中空（△▽）にして、
    /// 今が初期状態かどうかを一目で分かるようにする。
    /// 判定は列ごとの向きではなく一覧全体の並び順で行う。
    /// 「生まれ年」一覧の年齢列は西暦と逆を向くが、それは既定でも起きるため
    /// 列の向きで判定すると初期状態なのに中空になってしまう
    private func sortArrowSymbol(_ order: YearSortOrder) -> String {
        let pointsUp = order == .ascending
        let isDefault = sortOrder == YearSortOrder.default
        switch (pointsUp, isDefault) {
        case (true, true): return "arrowtriangle.up.fill"
        case (true, false): return "arrowtriangle.up"
        case (false, true): return "arrowtriangle.down.fill"
        case (false, false): return "arrowtriangle.down"
        }
    }

    /// 並び順に関わらない列の見出し
    private func plainLabel(_ title: LocalizedStringKey, labelSize labelFontSize: CGFloat) -> some View {
        Text(title)
            .font(.system(size: labelFontSize, weight: .semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}
