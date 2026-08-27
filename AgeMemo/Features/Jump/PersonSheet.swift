// 名簿から人を選んで現在年へ移動し、登録・変更・削除を行う

import SwiftUI

struct PersonSheet: View {
    @Environment(PersonStore.self) private var personStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var editorTarget: PersonEditorTarget?
    @State private var pendingDeletion: Person?

    let currentYear: Int
    let select: (Person) -> Void

    /// Listは常に画面いっぱいに広がるため、行数から必要最小限の高さを見積もる
    @ScaledMetric(relativeTo: .body) private var estimatedRowHeight: CGFloat = 58
    @ScaledMetric(relativeTo: .body) private var estimatedChromeHeight: CGFloat = 140

    private var fittedHeight: CGFloat {
        let rowCount = max(personStore.people.count, 1)
        return estimatedChromeHeight + estimatedRowHeight * CGFloat(rowCount)
    }

    var body: some View {
        NavigationStack {
            List {
                if personStore.people.isEmpty {
                    Section {
                        Text("名簿が空です。右上の＋から追加してください。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("名簿") {
                        ForEach(personStore.people) { person in
                            Button {
                                select(person)
                                dismiss()
                            } label: {
                                row(for: person)
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    pendingDeletion = person
                                } label: {
                                    Label("削除", systemImage: "trash")
                                }

                                Button {
                                    editorTarget = .edit(person)
                                } label: {
                                    Label("変更", systemImage: "pencil")
                                }
                                .tint(.accentColor)
                            }
                        }
                    }
                }

                if let message = personStore.lastErrorMessage {
                    Section {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("名簿")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editorTarget = .add
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editorTarget) { target in
                // シートは別ウインドウ層に出るため外観設定を明示的に引き継ぐ
                PersonEditorSheet(target: target)
                    .preferredColorScheme(settings.appearanceMode.colorScheme)
            }
            .alert("削除しますか？", isPresented: deletionBinding, presenting: pendingDeletion) { person in
                Button("削除", role: .destructive) {
                    personStore.delete(id: person.id)
                }
                Button("キャンセル", role: .cancel) {}
            } message: { person in
                Text("「\(person.name)」を削除します。この操作は取り消せません。")
            }
        }
        // 行数に応じた高さにする。増えすぎたときは .large へ逃がす
        .presentationDetents(fittedHeight > 520 ? [.large] : [.height(fittedHeight), .large])
        .presentationDragIndicator(.visible)
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private func row(for person: Person) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.body)
                Text("\(String(person.birthYear))年生まれ・\(currentYear - person.birthYear)歳")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

enum PersonEditorTarget: Identifiable {
    case add
    case edit(Person)

    var id: String {
        switch self {
        case .add: "add"
        case .edit(let person): person.id.uuidString
        }
    }
}

private struct PersonEditorSheet: View {
    @Environment(PersonStore.self) private var personStore

    @State private var name: String

    let target: PersonEditorTarget

    init(target: PersonEditorTarget) {
        self.target = target
        switch target {
        case .add:
            _name = State(initialValue: "")
        case .edit(let person):
            _name = State(initialValue: person.name)
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var title: String {
        switch target {
        case .add: "名簿に追加"
        case .edit: "名簿を変更"
        }
    }

    private var existingBirthDate: Date? {
        switch target {
        case .add: nil
        case .edit(let person): person.birthDate
        }
    }

    var body: some View {
        BirthDateInputSheet(
            title: title,
            birthDate: existingBirthDate,
            canSave: !trimmedName.isEmpty
        ) { birthDate in
            switch target {
            case .add:
                personStore.add(name: trimmedName, birthDate: birthDate)
            case .edit(let person):
                personStore.update(id: person.id, name: trimmedName, birthDate: birthDate)
            }
        } header: {
            TextField("名前", text: $name)
                .textFieldStyle(.roundedBorder)
                .onChange(of: name) { _, newValue in
                    if newValue.count > AppConfig.maximumPersonNameLength {
                        name = String(newValue.prefix(AppConfig.maximumPersonNameLength))
                    }
                }
        }
    }
}
