// 指定した年齢の人の生年へ移動する

import SwiftUI

struct AgeJumpSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""
    /// マイナス年齢＝これから生まれる方の年を指す
    @State private var isNegative = false
    @ScaledMetric(relativeTo: .largeTitle) private var displayFontSize: CGFloat = 44

    /// 前回入力した年齢。未入力ならこの値がそのまま使われる
    let placeholderAge: Int
    let currentYear: Int
    /// 入力した年齢と移動先の年を返す
    let jump: (Int, Int) -> Void

    private var isEmpty: Bool { digits.isEmpty }

    private var age: Int {
        guard let value = Int(digits) else { return clamped(placeholderAge) }
        let magnitude = min(value, AppConfig.maximumAgeInput)
        return clamped(isNegative ? -magnitude : magnitude)
    }

    /// 数え年には0歳がなく1歳から始まるため、下限を数え方に合わせる
    /// マイナスはまだ生まれていない年を指すので、そのまま通す
    private func clamped(_ age: Int) -> Int {
        settings.ageReckoning.clampedInputAge(age)
    }

    private var destinationYear: Int {
        AgeCalculator.birthYear(forAge: age, currentYear: currentYear, reckoning: settings.ageReckoning)
    }

    private var boundedDestinationYear: Int {
        min(max(destinationYear, AppConfig.yearRange.lowerBound), AppConfig.yearRange.upperBound)
    }

    var body: some View {
        NavigationStack {
            // 文字サイズを大きくすると小型端末では収まらないためスクロール可能にする
            ScrollView {
                VStack(spacing: 12) {
                    display
                        // タイトルとの間を詰め、移動ボタンを画面内へ収める
                        .padding(.top, -12)
                        .padding(.bottom, -4)

                    if destinationYear != boundedDestinationYear {
                        Text("表示範囲外のため \(String(boundedDestinationYear))年へ移動します")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    NumericKeypad(trailingKey: .sign) { key in handle(key) }

                    Button {
                        jump(age, boundedDestinationYear)
                        dismiss()
                    } label: {
                        Label("移動", systemImage: "arrow.up.forward")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    // 移動先行と同じ緑系にして操作と結果を対応させる
                    .tint(Color.moveAction)
                }
                .padding()
                .measuredSheetContent()
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .navigationTitle("年齢")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SheetCloseButton { dismiss() }
                }
            }
        }
        .fittedSheetHeight()
        .presentationDragIndicator(.visible)
    }

    private var display: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            // 未入力のあいだは前回値をグレーで示し、数字を押すと上書きする
            Text(isEmpty ? "\(age)" : "\(isNegative ? "−" : "")\(digits)")
                .font(.system(size: displayFontSize, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(isEmpty ? Color(.tertiaryLabel) : Color(.label))
                .contentTransition(.numericText())
                .animation(.snappy, value: digits)

            Text("歳")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func handle(_ key: NumericKeypadKey) {
        switch key {
        case .digit(let digit):
            append(digit)
        case .delete:
            if !digits.isEmpty { digits.removeLast() }
        case .auxiliary:
            break
        case .toggleSign:
            // 0は符号を持たせず、−0表示を防ぐ
            if digits != "0" { isNegative.toggle() }
        }
    }

    private func append(_ digit: Int) {
        // 空または "0" のときは置き換えて先頭ゼロを防ぐ
        let next = (digits.isEmpty || digits == "0") ? String(digit) : digits + String(digit)
        guard let value = Int(next), value <= AppConfig.maximumAgeInput else { return }
        let normalizedAge = clamped(isNegative ? -value : value)
        isNegative = normalizedAge < 0
        digits = String(abs(normalizedAge))
    }
}
