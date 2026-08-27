// 正負の整数を入力する専用テンキーを提供する

import SwiftUI

struct SignedNumberPad: View {
    @Binding var value: Int
    let maximumAbsoluteValue: Int
    let confirmTitle: String
    let confirm: () -> Void

    private let rows = [[7, 8, 9], [4, 5, 6], [1, 2, 3]]

    var body: some View {
        VStack(spacing: 10) {
            Text(String(value))
                .font(.largeTitle.monospacedDigit().bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { digit in
                        key(String(digit)) { append(digit) }
                    }
                }
            }

            HStack(spacing: 10) {
                key("⌫") { deleteLast() }
                key("0") { append(0) }
                key("-/+") { toggleSign() }
            }

            Button(confirmTitle, action: confirm)
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
        }
    }

    private func key(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.title3.monospacedDigit().weight(.semibold))
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func append(_ digit: Int) {
        let sign = value < 0 ? -1 : 1
        let absoluteValue = abs(value)
        let candidate = absoluteValue * 10 + digit
        value = sign * min(candidate, maximumAbsoluteValue)
    }

    private func deleteLast() {
        let sign = value < 0 ? -1 : 1
        value = sign * (abs(value) / 10)
    }

    private func toggleSign() {
        if value != 0 {
            value *= -1
        }
    }
}
