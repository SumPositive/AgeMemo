// 西暦・和暦・年齢・干支とメモを一行に表示する

import SwiftUI

/// 一覧の列幅。行と見出しで同じ値を使い、見出しが中身の真上に来るようにする。
/// すべて基準フォントサイズに対する倍率で持ち、文字サイズが変わっても比率を保つ
enum YearColumnMetrics {
    /// 行の左右端に空ける幅。列間と違い、ここは詰めずに保つ
    static let edgeInset: CGFloat = 12
    /// 列間の既定値。幅に余りがなければここから詰めていく
    static let columnSpacing: CGFloat = 10

    /// 列間を詰めきったときに残す幅。これ以上詰めると隣の列と地続きに見える
    static let minimumColumnSpacing: CGFloat = 8

    static let gregorianWidthRatio: CGFloat = 2.55
    static let eraWidthRatio: CGFloat = 4.1
    /// 年齢は「99歳」を原則の幅とし、桁が増える行だけ広がる
    static let ageMinWidthRatio: CGFloat = 2.3

    /// 干支と九星を積むときの九星の縮小率。列幅もこれを基準に決まる
    static let nineStarScale: CGFloat = 0.70
    /// 干支だけのときの列幅倍率
    static let zodiacOnlyWidthRatio: CGFloat = 2.6
    /// 学齢・賀寿・厄年の縮小率
    static let badgeScale: CGFloat = 0.66

    /// 文字を縮められる下限。これ以上小さくすると一覧として読めなくなる
    static let minimumTextScale: CGFloat = 0.5

    /// 干支・九星列の幅。九星を出すかどうかで基準が変わる
    static func zodiacWidth(fontSize: CGFloat, showsNineStar: Bool) -> CGFloat {
        showsNineStar ? fontSize * nineStarScale * 4 : fontSize * zodiacOnlyWidthRatio
    }

    /// 学齢・賀寿・厄年の列幅。最長の「大還暦」（3文字）に合わせる
    static func badgeWidth(fontSize: CGFloat) -> CGFloat {
        fontSize * badgeScale * 3
    }

    /// 出す列の構成。行と見出しで同じ値を使う
    struct Columns: Equatable {
        var showsZodiac: Bool
        var showsNineStar: Bool
        var reservesBadgeColumn: Bool

        /// 干支・九星をまとめた1列を出すか
        var showsZodiacColumn: Bool { showsZodiac || showsNineStar }
        /// 干支と九星を縦に積むか
        var stacksNineStar: Bool { showsZodiac && showsNineStar }

        /// 端の余白を除いた列間の数。列が n 個なら n-1 か所
        var spacingCount: Int {
            var count = 2  // 西暦-和暦, 和暦-年齢
            if showsZodiacColumn { count += 1 }
            if reservesBadgeColumn { count += 1 }
            return count
        }
    }

    /// 幅に対する列の置き方。行と見出しはこの1つの答えだけを見る
    struct Layout: Equatable {
        /// 文字と列幅の縮小率。1 なら指定サイズそのまま
        var scale: CGFloat
        /// 列と列の間に空ける幅
        var columnSpacing: CGFloat
        /// 実際に出す列
        var columns: Columns

        /// 縮小後の基準フォントサイズ
        func fontSize(base: CGFloat) -> CGFloat { base * scale }
    }

    /// 余りがあるときに列間へ配る上限。これ以上離すと列の対応が読み取りにくい
    static let maximumColumnSpacing: CGFloat = 28

    /// 一覧の最大幅。iPhone 17 Pro Max の画面幅にそろえる。
    /// iPad でもこの幅までで頭打ちにし、対応すべきレイアウトを
    /// iPhone の範囲だけに絞る
    static let maximumListWidth: CGFloat = 440

    /// 列の幅だけの合計（端の余白と列間を含まない）
    static func columnsWidth(fontSize: CGFloat, columns: Columns) -> CGFloat {
        var width = fontSize * gregorianWidthRatio
        width += fontSize * eraWidthRatio
        width += fontSize * ageMinWidthRatio
        if columns.showsZodiacColumn {
            width += zodiacWidth(fontSize: fontSize, showsNineStar: columns.stacksNineStar)
        }
        if columns.reservesBadgeColumn {
            width += badgeWidth(fontSize: fontSize)
        }
        return width
    }

    /// その幅における列の置き方を決める。
    ///
    /// 手順は2段。
    /// 1. 指定された文字サイズのまま列を並べ、余り（または不足）を列間で吸収する。
    ///    余れば列間を広げ、足りなければ最小の列間まで詰める
    /// 2. 列間を最小まで詰めても入らないぶんだけ、列幅と文字を均等に縮める
    ///
    /// こうすると、広い画面では指定サイズの読みやすさを保ったまま列が散り、
    /// 狭い画面では余白から先に削られて文字の縮小は最後になる
    static func layout(
        availableWidth: CGFloat,
        fontSize: CGFloat,
        wantsZodiac: Bool,
        wantsNineStar: Bool,
        wantsBadgeColumn: Bool
    ) -> Layout {
        let wanted = Columns(
            showsZodiac: wantsZodiac,
            showsNineStar: wantsNineStar,
            reservesBadgeColumn: wantsBadgeColumn
        )
        // 測る前は指定どおりに置く。幅が分かった時点で組み直される
        guard availableWidth > 0 else {
            return Layout(scale: 1, columnSpacing: columnSpacing, columns: wanted)
        }

        // 補助列は右から順に落とせる。設定で出す指定でも、
        // 文字を縮めきっても入らないなら列ごと下ろしたほうが読める
        for columns in fallbacks(from: wanted) {
            let inner = availableWidth - edgeInset * 2
            let spacingCount = CGFloat(columns.spacingCount)
            let columnsAtFullSize = columnsWidth(fontSize: fontSize, columns: columns)

            // 第1段：文字は指定サイズのまま、列間だけで調整する
            let spacingBudget = inner - columnsAtFullSize
            if spacingBudget >= minimumColumnSpacing * spacingCount {
                let spacing = min(maximumColumnSpacing, spacingBudget / spacingCount)
                return Layout(scale: 1, columnSpacing: spacing, columns: columns)
            }

            // 第2段：列間は最小のまま、列幅と文字を均等に縮める
            let widthForColumns = inner - minimumColumnSpacing * spacingCount
            guard widthForColumns > 0, columnsAtFullSize > 0 else { continue }
            let scale = widthForColumns / columnsAtFullSize
            if scale >= minimumTextScale {
                return Layout(scale: scale, columnSpacing: minimumColumnSpacing, columns: columns)
            }
            // 下限まで縮めても入らないので、次の候補（列を1つ落とした構成）へ
        }

        // 基本3列を最小の文字で置く。これ以上は削れない
        let basic = Columns(showsZodiac: false, showsNineStar: false, reservesBadgeColumn: false)
        return Layout(scale: minimumTextScale, columnSpacing: minimumColumnSpacing, columns: basic)
    }

    /// 補助列を右から順に下ろした候補。左にある基本3列は必ず残す
    private static func fallbacks(from wanted: Columns) -> [Columns] {
        var candidates = [wanted]
        if wanted.reservesBadgeColumn {
            candidates.append(Columns(
                showsZodiac: wanted.showsZodiac,
                showsNineStar: wanted.showsNineStar,
                reservesBadgeColumn: false
            ))
        }
        if wanted.stacksNineStar {
            // 干支と九星を積んでいたら、まず九星だけ下ろす
            candidates.append(Columns(showsZodiac: true, showsNineStar: false, reservesBadgeColumn: false))
        }
        if wanted.showsZodiacColumn {
            candidates.append(Columns(showsZodiac: false, showsNineStar: false, reservesBadgeColumn: false))
        }
        return candidates
    }
}

/// 行の下に添えるカプセルの内容
struct AlternateAgeHint: Equatable {
    enum Kind: Equatable {
        /// 年齢一覧のジャンプ先の行に付ける。
        /// 月日が分からないため常に「かもしれない」扱い。
        /// selectedAge はその行に表示されている年齢
        case ageJump(selectedAge: Int)
        /// 自分／名簿一覧の当年の行に付ける。
        /// 実際の生年月日から「今日はまだ誕生日前」と判定できたときだけ出す
        case beforeBirthdayToday
        /// 同じ位置で、今年の誕生日をすでに迎えているときに出す
        case afterBirthdayToday
        /// 記念日を選んでいるとき。月日を見ないため、その年のうちは常に同じ周年数
        case anniversaryThisYear
    }

    let kind: Kind
    /// beforeBirthdayToday は誕生日前とみなした場合の満年齢、
    /// afterBirthdayToday と anniversaryThisYear は当年の値、
    /// ageJump は生まれ年（西暦）
    let value: Int
    /// 数え年の行を先頭に添えるか。設定「数え年を表示する」に従う
    var showsTraditionalAge: Bool = false
}

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
    /// 還暦・喜寿などの節目。該当しない年は nil
    var longevity: Longevity?
    /// 前厄・本厄・後厄。性別が未指定なら nil
    var unluckyYear: UnluckyYear?
    /// 小学校1年から大学4年までの学年。設定がOFFなら nil
    var schoolMilestone: SchoolMilestone?
    /// 九星の本命星。設定がOFFなら nil
    var nineStar: NineStar?
    /// もう一方の年齢の可能性を年齢列の下に添える。
    /// 年齢一覧のジャンプ先には「まだ誕生日前ならこの歳」、自分／名簿一覧の当年には
    /// 「今日はまだ誕生日前なのでこの歳」を表示する
    var alternateAgeHint: AlternateAgeHint?
    /// age 列の単位。記念日を選んでいるときは「歳」ではなく「周年」にする
    var showsAnniversaryUnit: Bool = false
    let compact: Bool
    /// 列の置き方。幅から決まる縮小率・列間・列構成をまとめて受け取る。
    /// 見出しと同じ値を使うことで、列の位置と有無が必ずそろう
    var layout = YearColumnMetrics.Layout(
        scale: 1,
        columnSpacing: YearColumnMetrics.columnSpacing,
        columns: YearColumnMetrics.Columns(
            showsZodiac: false,
            showsNineStar: false,
            reservesBadgeColumn: false
        )
    )
    @ScaledMetric(relativeTo: .body) private var preferredFontSize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption2) private var preferredHintFontSize: CGFloat = 11

    /// 行の左右端に空ける幅
    private let edgeInset = YearColumnMetrics.edgeInset

    private var hasMemo: Bool {
        !(memo?.isEmpty ?? true)
    }

    /// 2行目はメモのためだけに使う
    private var hasSecondaryLine: Bool { hasMemo }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 5) {
            // カプセルはこの行を説明するものなので、行の背景に含まれるよう先頭へ置く。
            // 親は leading 揃えなので、行の中央へ寄せ直す
            if let alternateAgeHint {
                alternateAgeHintCapsule(alternateAgeHint)
                    // 行の自然幅ではなく、一覧に使える幅からカプセル幅を決める。
                    // スクロール領域の実幅を見ると、幅を絞った iPad で行より広くなる
                    .containerRelativeFrame(.horizontal) { length, _ in
                        min(length, YearColumnMetrics.maximumListWidth) - edgeInset * 2
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // 列の幅・列間・縮小率はすべて layout が決めている。
            // 行はそれをそのまま置くだけで、幅の判断はしない
            primaryLine

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
        // VStack は中身の自然幅で決まるため、先に親の幅いっぱいへ広げてから
        // 背景を敷く。こうしないとカプセルなど長い中身が行からはみ出す
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// 説明文の各行が折り返さない倍率を上から順に試す。
    /// カプセルは1行の文なので、列よりも小さくして良い
    private var hintScales: [CGFloat] {
        [1.0, 0.95, 0.9, 0.85, 0.8, 0.75, 0.7, 0.65, 0.6, 0.55, 0.5, 0.45, 0.4]
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

    /// 列を1行に並べる。
    ///
    /// 列間は layout が決めた確定値を置く。Spacer（最小値）にすると
    /// 実際の幅が親の提案次第で変わり、行と見出しでずれる。
    /// 端の余白だけは可変にして、合計が親より狭いときの余りを左右へ均等に流す
    private var primaryLine: some View {
        let fontSize = layout.fontSize(base: preferredFontSize)
        let columns = layout.columns
        let spacing = layout.columnSpacing

        return HStack(spacing: 0) {
            Spacer(minLength: edgeInset)

            gregorianColumn(fontSize: fontSize)
            columnGap(spacing)
            eraColumn(fontSize: fontSize)
                .frame(width: fontSize * YearColumnMetrics.eraWidthRatio, alignment: .leading)
            columnGap(spacing)
            ageColumn(fontSize: fontSize)

            if columns.showsZodiacColumn {
                columnGap(spacing)
                zodiacColumn(fontSize: fontSize, columns: columns)
            }

            if columns.reservesBadgeColumn {
                columnGap(spacing)
                badgeColumn(fontSize: fontSize)
            }

            Spacer(minLength: edgeInset)
        }
        // 端の Spacer が伸びるには親からの幅の提案が要る。
        // 行の VStack は leading 揃えなので、ここで明示的に広げておく
        .frame(maxWidth: .infinity)
    }

    /// 列と列の間。確定した幅を置くので、行と見出しで必ず同じ位置になる
    private func columnGap(_ width: CGFloat) -> some View {
        Color.clear.frame(width: width, height: 0)
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
        let badgeFontSize = fontSize * YearColumnMetrics.badgeScale
        return VStack(alignment: .leading, spacing: 0) {
            badgeGroup(font: .system(size: badgeFontSize))
        }
        .lineLimit(1)
        .frame(width: YearColumnMetrics.badgeWidth(fontSize: fontSize), alignment: .leading)
    }

    private func gregorianColumn(fontSize: CGFloat) -> some View {
        Text(String(row.gregorian))
            .font(.system(size: fontSize, weight: .semibold, design: .monospaced))
            .lineLimit(1)
            // 幅が変わった直後は縮小率がまだ追いついていないことがある。
            // その1フレームで桁が切れないよう、枠の中で縮む余地を持たせる
            .minimumScaleFactor(0.7)
            .frame(width: fontSize * YearColumnMetrics.gregorianWidthRatio, alignment: .trailing)
    }

    @ViewBuilder
    private func zodiacColumn(fontSize: CGFloat, columns: YearColumnMetrics.Columns) -> some View {
        // 干支と九星も常に縦積み。幅は九星の「一白水星」（4文字）に合わせて
        // 固定し、行ごとに列位置がずれないようにする。
        // 何を出すかは layout が決めており、行はそれに従うだけ
        let width = YearColumnMetrics.zodiacWidth(fontSize: fontSize, showsNineStar: columns.stacksNineStar)

        if columns.stacksNineStar, let nineStar {
            VStack(alignment: .leading, spacing: 0) {
                zodiacText(size: fontSize * 0.82)
                nineStarText(nineStar, size: fontSize * YearColumnMetrics.nineStarScale)
            }
            .frame(width: width, alignment: .leading)
        } else if columns.showsZodiac {
            // 絵文字＋漢字1文字ぶん
            zodiacText(size: fontSize)
                .frame(width: width, alignment: .leading)
        } else if let nineStar {
            nineStarText(nineStar, size: fontSize * 0.72)
                .frame(width: width, alignment: .leading)
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

    /// 行の先頭に置く説明カプセル
    private func alternateAgeHintCapsule(_ hint: AlternateAgeHint) -> some View {
        // カプセルは説明対象の行そのものに付くので、その行の背景色に合わせる
        // （移動先は緑、当年はアクセントカラー）
        let tintColor = alternateAgeHintColor(hint)

        // 明示した改行だけを残し、各行が収まる倍率まで全体を縮小する
        return ViewThatFits(in: .horizontal) {
            ForEach(hintScales, id: \.self) { scale in
                Text(alternateAgeHintText(hint))
                    .font(.system(size: preferredHintFontSize * scale, weight: .semibold))
                    .lineLimit(3)
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
            // 背景の色は薄く保ちつつ、文字は本文と同じ濃さにしてコントラストを確保する
            .foregroundStyle(Color.primary)
            // 行ごとに長さが違うので、行頭をそろえて読みやすくする
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            // 背景と枠線は最も長い行に必要な幅だけ確保する
            // 行そのものが色付きの背景なので、カプセルは地の色で抜いて
            // 枠線だけを行の色に合わせる。同系色を重ねると境界が消えてしまう
            .background(
                Color(.systemBackground).opacity(0.75),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tintColor.opacity(0.7), lineWidth: 1)
            }
    }

    /// 指す先の行の背景色に揃える。rowBackground の isSelected／isCurrentYear と対応させる
    private func alternateAgeHintColor(_ hint: AlternateAgeHint) -> Color {
        switch hint.kind {
        case .ageJump:
            Color(uiColor: .systemGreen)
        case .beforeBirthdayToday, .afterBirthdayToday, .anniversaryThisYear:
            // いずれも当年行を指すので、当年行の背景と同じ色にする
            Color.accentColor
        }
    }

    private func alternateAgeHintText(_ hint: AlternateAgeHint) -> LocalizedStringKey {
        switch hint.kind {
        case .ageJump(let selectedAge):
            // この行そのものが何の年かを1文で説明する
            "今年の誕生日で満\(String(selectedAge))歳になる方が生まれた年です"
        case .beforeBirthdayToday:
            // value は誕生日前の満年齢。誕生日を迎えると +1 になり、
            // 数え年は元日にその値へ達しているので +2 にあたる
            if hint.showsTraditionalAge {
                "今年の元日で数え\(String(hint.value + 2))歳です\n今年の誕生日で満\(String(hint.value + 1))歳になります\n今日は誕生日前なので満\(String(hint.value))歳です"
            } else {
                "今年の誕生日で満\(String(hint.value + 1))歳になります\n今日は誕生日前なので満\(String(hint.value))歳です"
            }
        case .afterBirthdayToday:
            // すでに今年の誕生日を迎えているので、当年の満年齢がそのまま今の年齢
            if hint.showsTraditionalAge {
                "今年の元日で数え\(String(hint.value + 1))歳です\n今年の誕生日で満\(String(hint.value))歳になりました"
            } else {
                "今年の誕生日で満\(String(hint.value))歳になりました"
            }
        case .anniversaryThisYear:
            "今年の記念日で\(String(hint.value))周年です"
        }
    }

    @ViewBuilder
    private func ageColumn(fontSize: CGFloat) -> some View {
        if let age {
            let ageText = (showsAnniversaryUnit ? Text("\(String(age))周年") : Text("\(String(age))歳"))
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundStyle(age < 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(rowTextColor))
                .lineLimit(1)

            // 「99歳」の幅を原則とし、必要な行だけ広げる
            // 年齢は桁数で幅が変わるので、自然幅を確保してから下限を当てる。
            // fixedSize があると minimumScaleFactor は効かないが、
            // この列は下限より広がれるので枠に負けて切れることはない
            ageText
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: fontSize * YearColumnMetrics.ageMinWidthRatio, alignment: .trailing)
        } else {
            // 年齢未設定時も列配置を保つ
            Color.clear
                .frame(width: fontSize * YearColumnMetrics.ageMinWidthRatio)
        }
    }

    private func eraColumn(fontSize: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(row.eraSpans.enumerated()), id: \.offset) { _, span in
                Text(span.displayText)
                    .font(.system(size: fontSize))
                    .lineLimit(1)
                    // 幅が変わった直後の1フレームでも元号名が切れないようにする
                    .minimumScaleFactor(0.7)
            }
        }
    }
}
