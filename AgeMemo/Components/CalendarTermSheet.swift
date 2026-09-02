// 暦の用語をタップしたときに出す解説シート

import SwiftUI

/// 漢字・読み・字の意味・本文・制度の説明を、表示言語に合わせて見せる。
/// 六曜・元号・九星・干支・厄年・賀寿で共通に使う
struct CalendarTermSheet: View {
    let term: CalendarTerm

    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize
    @State private var sheetContentHeight: CGFloat = 220

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                Divider()

                Text(term.detail)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if let footnote = term.footnote {
                    Divider()

                    Text(footnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 六曜・九星・厄年などは占いや言い伝えで、由来にも諸説ある。
                // 断定と受け取られないよう、解説には必ず添える
                Text("この解説は一般に伝えられている説明にもとづくものです。暦の解釈や由来には諸説あります。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            // onGeometryChange は iOS 18 以降のため、17 でも動く方法で高さを測る
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: CalendarTermSheetHeightKey.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(CalendarTermSheetHeightKey.self) { height in
                sheetContentHeight = height
            }
        }
        .scrollIndicators(.hidden)
        .dynamicTypeSize(sheetDynamicTypeSize)
        .presentationDetents([.height(min(max(sheetContentHeight + 84, 200), 620)), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 用語そのものは暦の言葉なので訳さず、読みだけ言語に合わせる
            Text(verbatim: term.kanji)
                .font(.largeTitle.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(verbatim: CalendarTermLocale.reading(kana: term.kana, romaji: term.romaji))
                .font(.headline)
                .foregroundStyle(.secondary)

            if let subtitle = term.subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sheetDynamicTypeSize: DynamicTypeSize {
        let baseSize = settings.fontScale.followsSystem
            ? systemDynamicTypeSize
            : settings.fontScale.dynamicTypeSize
        // 解説は読みやすさと崩れにくさを両立するため上限を設ける
        return min(baseSize, .xxxLarge)
    }
}

private struct CalendarTermSheetHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// 漢字語をタップで開けるようにする。見た目は変えず、操作だけを足す
    func calendarTermTappable(_ term: CalendarTerm?, selection: Binding<CalendarTerm?>) -> some View {
        modifier(CalendarTermTappableModifier(term: term, selection: selection))
    }
}

private struct CalendarTermTappableModifier: ViewModifier {
    let term: CalendarTerm?
    @Binding var selection: CalendarTerm?

    func body(content: Content) -> some View {
        if let term {
            Button {
                selection = term
            } label: {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("用語の意味を見る"))
        } else {
            content
        }
    }
}
