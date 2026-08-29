// 一覧の年齢表示状態を選ぶ3種類のタブを等幅で配置する

import SwiftUI

enum MainToolbarAction: CaseIterable, Identifiable {
    case age
    case personal
    case person

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .age: "年齢"
        case .personal: "自分"
        case .person: "名簿"
        }
    }

    var symbol: String {
        switch self {
        case .age: "number"
        case .personal: "person"
        case .person: "person.2"
        }
    }
}

struct BottomToolbar: View {
    let displayMode: DisplayMode
    let selection: MainToolbarAction
    let action: (MainToolbarAction) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainToolbarAction.allCases) { item in
                Button {
                    action(item)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.body)
                        if displayMode == .beginner {
                            Text(item.title)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .foregroundStyle(selection == item ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
