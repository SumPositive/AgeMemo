// メモと名簿を1つのファイルへ書き出し、読み込んで元へ戻す

import SwiftUI

struct BackupSection: View {
    @Environment(MemoStore.self) private var memoStore
    @Environment(PersonStore.self) private var personStore

    @State private var exportedFile: BackupFile?
    @State private var isExporting = false
    @State private var isImporting = false
    /// 取り込む前に中身を確かめてから上書きする
    @State private var pendingImport: BackupDocument?
    @State private var lastError: BackupError?
    @State private var completionMessage: LocalizedStringKey?

    var body: some View {
        Section {
            Button("ファイルへ書き出す") {
                export()
            }

            Button("ファイルから読み込む") {
                isImporting = true
            }

            if let lastError {
                Text(lastError.message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let completionMessage {
                Text(completionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            // 説明は他の設定項目と同じく見出しの右に添える
            HStack(alignment: .center, spacing: 4) {
                Text("メモと名簿の保存")
                BeginnerHelpBanner("メモと名簿をまとめて1つのファイルへ書き出します。「ファイル」アプリやiCloud Driveへ保存しておくと、機種変更のときに新しい端末で読み込んで元へ戻せます。読み込むと、いま入っているメモと名簿はすべて置き換わります。")
            }
        }
        .fileExporter(
            isPresented: $isExporting,
            document: exportedFile,
            contentType: .json,
            defaultFilename: BackupCoder.fileName()
        ) { result in
            switch result {
            case .success:
                lastError = nil
                completionMessage = "書き出しました"
            case .failure:
                // 利用者が取り消した場合もここへ来るため、失敗として扱わない
                break
            }
            exportedFile = nil
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.json]
        ) { result in
            handleImportResult(result)
        }
        .alert("読み込みますか？", isPresented: importConfirmationBinding, presenting: pendingImport) { document in
            Button("読み込む", role: .destructive) {
                apply(document)
            }
            Button("キャンセル", role: .cancel) {}
        } message: { document in
            let summary = document.summary
            Text("メモ\(summary.memoCount)件と名簿\(summary.personCount)件を読み込みます。いま入っているメモと名簿はすべて置き換わり、この操作は取り消せません。")
        }
    }

    private var importConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { if !$0 { pendingImport = nil } }
        )
    }

    private func export() {
        completionMessage = nil
        // 編集直後でも取りこぼさないよう、書き出す前に保存を確定させる
        memoStore.flushPendingSave()
        let document = BackupDocument(
            memos: memoStore.snapshot(),
            people: personStore.snapshot()
        )
        do {
            exportedFile = BackupFile(data: try BackupCoder.encode(document))
            lastError = nil
            isExporting = true
        } catch {
            lastError = .encodeFailed
        }
    }

    private func handleImportResult(_ result: Result<URL, Error>) {
        completionMessage = nil
        guard case .success(let url) = result else {
            // 取り消しはここへ来るため、何も知らせない
            return
        }
        // 「ファイル」アプリ側のファイルは、読む間だけ許可をもらう
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let document = try BackupCoder.decode(try Data(contentsOf: url))
            guard document.version <= BackupDocument.currentVersion else {
                lastError = .unsupportedVersion
                return
            }
            lastError = nil
            pendingImport = document
        } catch {
            lastError = .decodeFailed
        }
    }

    private func apply(_ document: BackupDocument) {
        memoStore.replaceAll(with: document.memos)
        personStore.replaceAll(with: document.people)
        let summary = document.summary
        completionMessage = "メモ\(summary.memoCount)件と名簿\(summary.personCount)件を読み込みました"
    }
}
