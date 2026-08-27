// 指定した年齢に該当する西暦年へ移動する

import SwiftUI

struct AgeJumpSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var age = 0

    let jump: (Int) -> Void

    private var destinationYear: Int? {
        AgeCalculator.birthYear(from: settings.birthDate).map { $0 + age }
    }

    private var boundedDestinationYear: Int? {
        destinationYear.map { min(max($0, AppConfig.yearRange.lowerBound), AppConfig.yearRange.upperBound) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let destinationYear, let boundedDestinationYear {
                    Text("該当年 \(destinationYear)年")
                        .font(.headline)
                    if destinationYear != boundedDestinationYear {
                        Text("表示範囲外のため \(boundedDestinationYear)年へ移動します")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                SignedNumberPad(
                    value: $age,
                    maximumAbsoluteValue: AppConfig.maximumAgeInput,
                    confirmTitle: "移動"
                ) {
                    guard let boundedDestinationYear else { return }
                    jump(boundedDestinationYear)
                    dismiss()
                }
            }
            .padding()
            .navigationTitle("年齢から移動")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
