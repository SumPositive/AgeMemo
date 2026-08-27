// 主画面の6種類の操作を等幅で配置する

import SwiftUI

enum MainToolbarAction: CaseIterable, Identifiable {
    case current
    case personal
    case age
    case zodiac
    case era
    case settings

    var id: Self { self }

    var title: String {
        switch self {
        case .current: "現在"
        case .personal: "自分"
        case .age: "年齢"
        case .zodiac: "干支"
        case .era: "飛躍"
        case .settings: "設定"
        }
    }

    var symbol: String {
        switch self {
        case .current: "calendar.badge.clock"
        case .personal: "person"
        case .age: "number"
        case .zodiac: "square.grid.3x3"
        case .era: "arrow.up.forward"
        case .settings: "gearshape"
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
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
