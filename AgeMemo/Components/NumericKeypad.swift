// Packlinと同じ操作感のテンキー部品を提供する

import SwiftUI

enum NumericKeypadKey: Hashable {
    case digit(Int)
    case delete
    /// 桁移動などの補助キー
    case auxiliary(String)
}

/// 3×3 + 最終行のテンキー。最終行の中央キーは用途に応じて差し替える
struct NumericKeypad: View {
    let compact: Bool
    /// 最終行の中央に置くキー（nilなら0の隣を空ける）
    let auxiliaryTitle: String?
    let auxiliaryDisabled: Bool
    let onKey: (NumericKeypadKey) -> Void

    init(
        compact: Bool = false,
        auxiliaryTitle: String? = nil,
        auxiliaryDisabled: Bool = false,
        onKey: @escaping (NumericKeypadKey) -> Void
    ) {
        self.compact = compact
        self.auxiliaryTitle = auxiliaryTitle
        self.auxiliaryDisabled = auxiliaryDisabled
        self.onKey = onKey
    }

    private let rows = [[7, 8, 9], [4, 5, 6], [1, 2, 3]]

    private var spacing: CGFloat { compact ? 8 : 10 }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(row, id: \.self) { digit in
                        KeypadDigitButton(label: "\(digit)", compact: compact) { onKey(.digit(digit)) }
                    }
                }
            }

            HStack(spacing: spacing) {
                KeypadDigitButton(label: "0", compact: compact) { onKey(.digit(0)) }

                if let auxiliaryTitle {
                    KeypadAuxiliaryButton(label: auxiliaryTitle, compact: compact) {
                        onKey(.auxiliary(auxiliaryTitle))
                    }
                    .disabled(auxiliaryDisabled)
                } else {
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: compact ? 52 : 56)
                }

                KeypadDeleteButton(compact: compact) { onKey(.delete) }
            }
        }
    }
}

private struct KeypadDigitButton: View {
    let label: String
    let compact: Bool
    let action: () -> Void

    private var minHeight: CGFloat { compact ? 52 : 56 }
    private var font: Font { compact ? .title2.weight(.medium) : .title.weight(.medium) }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .monospacedDigit()
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct KeypadAuxiliaryButton: View {
    let label: String
    let compact: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    private var minHeight: CGFloat { compact ? 52 : 56 }
    private var font: Font { compact ? .title3.weight(.medium) : .title2.weight(.medium) }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(font)
                .foregroundStyle(isEnabled ? Color.accentColor : Color(.tertiaryLabel))
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct KeypadDeleteButton: View {
    let compact: Bool
    let action: () -> Void

    private var minHeight: CGFloat { compact ? 52 : 56 }
    private var font: Font { compact ? .title3 : .title2 }

    var body: some View {
        Button(action: action) {
            Image(systemName: "delete.left")
                .font(font)
                .frame(maxWidth: .infinity, minHeight: minHeight)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("削除")
    }
}
