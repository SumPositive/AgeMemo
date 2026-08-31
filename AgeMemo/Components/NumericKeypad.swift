// Packlinと同じ操作感のテンキー部品を提供する

import SwiftUI

enum NumericKeypadKey: Hashable {
    case digit(Int)
    case delete
    /// 桁移動などの補助キー
    case auxiliary(String)
    /// 符号の反転
    case toggleSign
}

/// 最終行の右端に置くキー
enum NumericKeypadTrailingKey {
    /// 桁移動などの補助キー
    case auxiliary(title: String, disabled: Bool)
    /// 符号の反転
    case sign
}

/// 3×3 + 最終行のテンキー。最終行の中央キーは用途に応じて差し替える
struct NumericKeypad: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let explicitCompact: Bool?
    /// 最終行の右端に置くキー（nilなら空ける）
    let trailingKey: NumericKeypadTrailingKey?
    let onKey: (NumericKeypadKey) -> Void

    init(
        compact: Bool? = nil,
        trailingKey: NumericKeypadTrailingKey? = nil,
        onKey: @escaping (NumericKeypadKey) -> Void
    ) {
        self.explicitCompact = compact
        self.trailingKey = trailingKey
        self.onKey = onKey
    }

    private let rows = [[7, 8, 9], [4, 5, 6], [1, 2, 3]]

    /// 特大などのアクセシビリティサイズでは、キーが画面に収まるよう詰めて配置する
    private var compact: Bool {
        explicitCompact ?? dynamicTypeSize.isAccessibilitySize
    }

    @ScaledMetric(relativeTo: .title) private var scaledHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .title2) private var scaledCompactHeight: CGFloat = 52

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

            // 最下段は左からBS・0・右キー
            HStack(spacing: spacing) {
                KeypadDeleteButton(compact: compact) { onKey(.delete) }

                KeypadDigitButton(label: "0", compact: compact) { onKey(.digit(0)) }

                switch trailingKey {
                case .auxiliary(let title, let disabled):
                    KeypadAuxiliaryButton(label: title, compact: compact) {
                        onKey(.auxiliary(title))
                    }
                    .disabled(disabled)
                case .sign:
                    KeypadAuxiliarySymbolButton(systemImage: "plus.forwardslash.minus", compact: compact) {
                        onKey(.toggleSign)
                    }
                    .accessibilityLabel("符号を反転")
                case nil:
                    Color.clear
                        .frame(maxWidth: .infinity, minHeight: compact ? scaledCompactHeight : scaledHeight)
                }
            }
        }
        // 囲っているScrollViewのタッチ保留を解除して反応を即時にする
        .disablesScrollTouchDelay()
    }
}

/// 指が僅かに動いてもキャンセルされないよう、タップダウンで即発火する。
/// SwiftUIのButtonは押下後のわずかなドラッグで取りこぼすため、
/// ScrollView内でも確実に反応するよう自前のジェスチャーで処理する
private struct KeypadPressBehavior: ViewModifier {
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .opacity(isPressed ? 0.55 : 1)
            // 背景を含む矩形全体をタップ判定にする
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isEnabled, !isPressed else { return }
                        isPressed = true
                        action()
                    }
                    .onEnded { _ in
                        isPressed = false
                    },
                // ScrollViewのスクロールより先にキー入力を受け取る
                including: .gesture
            )
            // VoiceOverのアクティベートでも同じ入力を実行する
            .accessibilityAction {
                guard isEnabled else { return }
                action()
            }
            .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

private extension View {
    func keypadPress(action: @escaping () -> Void) -> some View {
        modifier(KeypadPressBehavior(action: action))
    }
}

private struct KeypadDigitButton: View {
    let label: String
    let compact: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title) private var scaledHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .title2) private var scaledCompactHeight: CGFloat = 52

    private var minHeight: CGFloat { compact ? scaledCompactHeight : scaledHeight }
    private var font: Font { compact ? .title2.weight(.medium) : .title.weight(.medium) }

    var body: some View {
        Text(label)
            .font(font)
            .monospacedDigit()
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .keypadPress(action: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
    }
}

private struct KeypadAuxiliaryButton: View {
    let label: String
    let compact: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    @ScaledMetric(relativeTo: .title2) private var scaledHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .title3) private var scaledCompactHeight: CGFloat = 52

    private var minHeight: CGFloat { compact ? scaledCompactHeight : scaledHeight }
    private var font: Font { compact ? .title3.weight(.medium) : .title2.weight(.medium) }

    var body: some View {
        Text(label)
            .font(font)
            .foregroundStyle(isEnabled ? Color.accentColor : Color(.tertiaryLabel))
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Color(.quaternarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .keypadPress(action: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(label)
    }
}

/// 補助キーのSF Symbol版。文字版と見た目を揃える
private struct KeypadAuxiliarySymbolButton: View {
    let systemImage: String
    let compact: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    @ScaledMetric(relativeTo: .title2) private var scaledHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .title3) private var scaledCompactHeight: CGFloat = 52

    private var minHeight: CGFloat { compact ? scaledCompactHeight : scaledHeight }
    private var font: Font { compact ? .title3.weight(.medium) : .title2.weight(.medium) }

    var body: some View {
        Image(systemName: systemImage)
            .font(font)
            .foregroundStyle(isEnabled ? Color.accentColor : Color(.tertiaryLabel))
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Color(.quaternarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .keypadPress(action: action)
            .accessibilityAddTraits(.isButton)
    }
}

private struct KeypadDeleteButton: View {
    let compact: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var scaledHeight: CGFloat = 56
    @ScaledMetric(relativeTo: .title3) private var scaledCompactHeight: CGFloat = 52

    private var minHeight: CGFloat { compact ? scaledCompactHeight : scaledHeight }
    private var font: Font { compact ? .title3 : .title2 }

    var body: some View {
        Image(systemName: "delete.left")
            .font(font)
            // 数字と役割が違うことを示すため、補助キーと同じアクセント色にする
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Color(.quaternarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .keypadPress(action: action)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("削除")
    }
}

// MARK: - スクロールの遅延解除

/// ScrollViewは指が触れてからスクロールか判定するまでタッチを保留するため、
/// テンキーの反応が鈍り、僅かに指が動くと取りこぼしたように感じる。
/// この保留を無効化して押下を即座に届ける
private struct DisableScrollTouchDelay: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async {
            var parent = view.superview
            while let current = parent {
                if let scrollView = current as? UIScrollView {
                    scrollView.delaysContentTouches = false
                    scrollView.canCancelContentTouches = true
                    break
                }
                parent = current.superview
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    /// テンキーなど即応性が要る操作を含むスクロール領域で、タッチの保留を解除する
    func disablesScrollTouchDelay() -> some View {
        background(DisableScrollTouchDelay().frame(width: 0, height: 0))
    }
}
