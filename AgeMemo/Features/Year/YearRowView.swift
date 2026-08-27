// 西暦・和暦・年齢・干支とメモを一行に表示する

import SwiftUI

struct YearRowView: View {
    let row: YearRow
    let age: Int?
    let memo: String?
    let isCurrentYear: Bool
    let isBirthYear: Bool
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 5) {
            HStack(spacing: 8) {
                Text(String(row.gregorian))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .frame(width: 52, alignment: .trailing)

                Text(row.eraDisplayText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let age {
                    Text("\(age)歳")
                        .font(.body.monospacedDigit())
                        .foregroundStyle(age < 0 ? .secondary : .primary)
                        .frame(width: 58, alignment: .trailing)
                }

                Text("\(row.stemBranch.branch.emoji) \(row.stemBranch.branch.kanji)")
                    .frame(width: 52, alignment: .leading)
            }

            if isBirthYear || !(memo?.isEmpty ?? true) {
                HStack(spacing: 6) {
                    if isBirthYear {
                        Text("生年")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .foregroundStyle(.white)
                            .background(.tint, in: Capsule())
                    }

                    if let memo, !memo.isEmpty {
                        Text(memo)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.leading, 60)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 6 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrentYear ? Color.accentColor.opacity(0.14) : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
