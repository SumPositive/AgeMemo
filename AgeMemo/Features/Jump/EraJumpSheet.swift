// 西暦または元号年を換算して該当年へ移動する

import SwiftUI

private enum EraJumpSelection: Hashable {
    case gregorian
    case era(EraChoice)
}

struct EraJumpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: EraJumpSelection = .gregorian
    @State private var inputYear = Calendar.current.component(.year, from: .now)

    let rows: [YearRow]
    let jump: (Int) -> Void

    private var eraChoices: [EraChoice] {
        JapaneseEra.eraChoices(from: rows)
    }

    private var convertedYear: Int {
        switch selection {
        case .gregorian:
            inputYear
        case .era(let choice):
            choice.firstGregorianYear + inputYear - 1
        }
    }

    private var boundedYear: Int {
        min(max(convertedYear, AppConfig.yearRange.lowerBound), AppConfig.yearRange.upperBound)
    }

    private var previewText: String {
        switch selection {
        case .gregorian:
            "西暦\(inputYear)年 → \(convertedYear)年"
        case .era(let choice):
            "\(choice.name)\(inputYear)年 → \(convertedYear)年"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("年号", selection: $selection) {
                        Text("西暦").tag(EraJumpSelection.gregorian)
                        ForEach(eraChoices.reversed()) { choice in
                            Text(choice.name).tag(EraJumpSelection.era(choice))
                        }
                    }
                    .pickerStyle(.menu)

                    Text(previewText)
                        .font(.headline.monospacedDigit())

                    if convertedYear != boundedYear {
                        Text("表示範囲外のため \(boundedYear)年へ移動します")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    SignedNumberPad(
                        value: $inputYear,
                        maximumAbsoluteValue: 9999,
                        confirmTitle: "移動"
                    ) {
                        jump(boundedYear)
                        dismiss()
                    }
                }
                .padding()
            }
            .scrollIndicators(.hidden)
            .navigationTitle("飛躍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
    }
}
