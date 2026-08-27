// 指定した年齢の人の生年へ移動する

import SwiftUI

struct AgeJumpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""
    @ScaledMetric(relativeTo: .largeTitle) private var displayFontSize: CGFloat = 52

    /// 前回入力した年齢。未入力ならこの値がそのまま使われる
    let placeholderAge: Int
    let currentYear: Int
    /// 入力した年齢と移動先の年を返す
    let jump: (Int, Int) -> Void

    private var isEmpty: Bool { digits.isEmpty }

    private var age: Int {
        guard let value = Int(digits) else { return placeholderAge }
        return min(value, AppConfig.maximumAgeInput)
    }

    private var destinationYear: Int {
        AgeCalculator.birthYear(forAge: age, currentYear: currentYear)
    }

    private var boundedDestinationYear: Int {
        min(max(destinationYear, AppConfig.yearRange.lowerBound), AppConfig.yearRange.upperBound)
    }

    var body: some View {
        NavigationStack {
            // 文字サイズを大きくすると小型端末では収まらないためスクロール可能にする
            ScrollView {
                VStack(spacing: 16) {
                    display

                    if destinationYear != boundedDestinationYear {
                        Text("表示範囲外のため \(String(boundedDestinationYear))年へ移動します")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    NumericKeypad { key in handle(key) }

                    Button {
                        jump(age, boundedDestinationYear)
                        dismiss()
                    } label: {
                        Text("移動")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .measuredSheetContent()
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicators(.hidden)
            .navigationTitle("年齢から移動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .fittedSheetHeight()
        .presentationDragIndicator(.visible)
    }

    private var display: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            // 未入力のあいだは前回値をグレーで示し、数字を押すと上書きする
            Text(isEmpty ? "\(placeholderAge)" : digits)
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
        }
    }

    private func append(_ digit: Int) {
        // 空または "0" のときは置き換えて先頭ゼロを防ぐ
        let next = (digits.isEmpty || digits == "0") ? String(digit) : digits + String(digit)
        guard let value = Int(next), value <= AppConfig.maximumAgeInput else { return }
        digits = String(value)
    }
}
