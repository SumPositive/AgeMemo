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
        // 列幅は基準サイズに比例するため、大きな文字と狭い画面が重なると
        // 合計が画面幅を超えて両端の見出しが切れる。実際に使える幅を測り、
        // 収まる基準サイズへ頭打ちにしてから列を組む
        GeometryReader { proxy in
            let fitted = fittedFontSize(availableWidth: proxy.size.width)
            // 見出しの文字も列幅と同じ比率で抑える。列幅だけを詰めると
            // 年齢列のように自然幅で場所を取る見出しが枠を押し広げてしまう
            columns(fontSize: fitted, labelSize: labelFontSize * fitted / rowFontSize)
                .frame(width: proxy.size.width)
        }
        // GeometryReader は縦に広がろうとするため、必要な高さを明示する。
        // 幅は測るまで分からないので、高さは頭打ち前の文字で確保しておく
        .frame(height: headerHeight(labelSize: labelFontSize))
    }

    /// 画面幅に収まるまで頭打ちにした、列幅の基準サイズ
    private func fittedFontSize(availableWidth: CGFloat) -> CGFloat {
        YearColumnMetrics.fittedFontSize(
            rowFontSize,
            availableWidth: availableWidth,
            showsZodiac: showsZodiac,
            showsNineStar: showsNineStar,
            reservesBadgeColumn: reservesBadgeColumn
        )
    }

    /// 見出しの高さ。文字とその上下の余白から決める。
    /// 幅に収まらず文字を抑えたときは、その分だけ高さも詰める
    private func headerHeight(labelSize: CGFloat) -> CGFloat {
        labelSize * 1.4 + (compact ? 4 : 6) * 2
    }

    private func columns(fontSize rowFontSize: CGFloat, labelSize labelFontSize: CGFloat) -> some View {
        // 行と同じ列幅・列間・端余白で並べ、見出しが中身の真上に来るようにする。
        // 行は ViewThatFits で縮むことがあるが、見出しは基準サイズのまま置く
        HStack(spacing: 0) {
            Spacer(minLength: YearColumnMetrics.edgeInset)

            headerLabel("西暦", order: sortOrder, labelSize: labelFontSize)
                .frame(width: rowFontSize * YearColumnMetrics.gregorianWidthRatio, alignment: .trailing)
            Spacer(minLength: YearColumnMetrics.columnSpacing)
            headerLabel("和暦", order: sortOrder, labelSize: labelFontSize)
                .frame(width: rowFontSize * YearColumnMetrics.eraWidthRatio, alignment: .leading)
            Spacer(minLength: YearColumnMetrics.columnSpacing)
            headerLabel(ageTitle, order: ageOrder, labelSize: labelFontSize)
                // 年齢列だけは下限幅しか決めていないため、他の固定幅列に押されると
                // minimumScaleFactor が働いて見出しだけが縮む。行と同じく
                // 自然な幅を先に確保して、押し潰されないようにする
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: rowFontSize * YearColumnMetrics.ageMinWidthRatio, alignment: .trailing)

            if showsZodiacColumn {
                Spacer(minLength: YearColumnMetrics.columnSpacing)
                // 干支・九星は年そのものの属性で並び順を持たないため、矢印は付けない
                plainLabel(showsZodiac ? "干支" : "九星", labelSize: labelFontSize)
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
                plainLabel("節目", labelSize: labelFontSize)
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
