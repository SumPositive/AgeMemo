// 複数の十二支に該当する年をシート内で絞り込む

import SwiftUI

struct ZodiacSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBranches: Set<EarthlyBranch> = []

    let rows: [YearRow]
    let jump: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    private var filteredRows: [YearRow] {
        rows.filter { selectedBranches.contains($0.stemBranch.branch) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(EarthlyBranch.allCases) { branch in
                        Button {
                            toggle(branch)
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(branch.emoji)\(branch.kanji)")
                                    .font(.headline)
                                Text(branch.kana)
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedBranches.contains(branch) ? .accentColor : .secondary)
                    }
                }
                .padding(.horizontal)

                if selectedBranches.isEmpty {
                    ContentUnavailableView("干支を選んでください", systemImage: "square.grid.3x3")
                } else {
                    Text("\(filteredRows.count)件")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)

                    List(filteredRows) { row in
                        Button {
                            jump(row.gregorian)
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Text(row.stemBranch.branch.emoji)
                                Text(String(row.gregorian))
                                    .monospacedDigit()
                                Text(row.eraDisplayText)
                                    .lineLimit(1)
                                Spacer()
                                if let age = AgeCalculator.age(in: row.gregorian, birthDate: settings.birthDate) {
                                    Text("\(age)歳")
                                        .monospacedDigit()
                                        .foregroundStyle(age < 0 ? .secondary : .primary)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                        .listRowBackground(
                            row.gregorian == Calendar.current.component(.year, from: .now)
                                ? Color.accentColor.opacity(0.14)
                                : Color.clear
                        )
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("干支")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ branch: EarthlyBranch) {
        if selectedBranches.contains(branch) {
            selectedBranches.remove(branch)
        } else {
            selectedBranches.insert(branch)
        }
    }
}
