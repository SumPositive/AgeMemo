// 初心者ヘルプ表示
// 見出しの右に疑問符アイコンを置き、詳しい説明はシートで見せる

import SwiftUI

struct BeginnerHelpBanner: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var systemDynamicTypeSize

    let message: LocalizedStringKey
    @State private var showsHelpSheet = false
    @State private var sheetContentHeight: CGFloat = 220

    init(_ message: LocalizedStringKey) {
        self.message = message
    }

    var body: some View {
        // 達人でも詳細は確認できるよう、アイコン自体は残す
        helpButton
            .sheet(isPresented: $showsHelpSheet) {
                helpSheet
                    // シートは親の文字サイズ環境を引き継がないため明示する
                    .dynamicTypeSize(helpDynamicTypeSize)
                    // 本文に合わせた高さを基本にし、長文は大きいシートへ逃がす
                    .presentationDetents([.height(helpSheetHeight), .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Color(.systemBackground))
            }
    }

    private var isBeginner: Bool {
        settings.displayMode == .beginner
    }

    private var helpButton: some View {
        Button {
            showsHelpSheet = true
        } label: {
            Image(systemName: "questionmark.circle")
                .font(helpButtonFont)
                .foregroundStyle(Color.accentColor)
                .opacity(isBeginner ? 1 : 0.72)
                .padding(isBeginner ? 8 : 5)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("ヘルプ"))
    }

    private var helpButtonFont: Font {
        // 達人モードのアイコンは少し控えめにする
        isBeginner ? .callout.weight(.semibold) : .footnote.weight(.semibold)
    }

    private var helpSheetHeight: CGFloat {
        min(max(sheetContentHeight + 84, 180), 620)
    }

    private var helpDynamicTypeSize: DynamicTypeSize {
        let baseSize = settings.fontScale.followsSystem
            ? systemDynamicTypeSize
            : settings.fontScale.dynamicTypeSize
        // ヘルプは読みやすさと崩れにくさを両立するため上限を設ける
        return min(baseSize, .xxxLarge)
    }

    private var helpSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Image(systemName: "questionmark.circle")
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                }

                Text(message)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            // onGeometryChange は iOS 18 以降のため、17 でも動く方法で高さを測る
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: HelpContentHeightKey.self, value: proxy.size.height)
                }
            }
            .onPreferenceChange(HelpContentHeightKey.self) { height in
                sheetContentHeight = height
            }
        }
        .scrollIndicators(.hidden)
    }
}

private struct HelpContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
