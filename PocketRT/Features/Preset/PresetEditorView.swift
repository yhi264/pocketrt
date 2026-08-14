import SwiftUI
import UniformTypeIdentifiers

/// 自施設プリセットの管理と、内蔵プリセットの表示切り替え。
struct PresetEditorView: View {
    let model: PresetStoreModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing: InstitutionalPreset?
    @State private var showAdd = false
    @State private var pendingDeletion: InstitutionalPreset?
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var pendingImport: PendingImport?

    /// 取り込み前の確認に使う、検証済みの内容。
    private struct PendingImport {
        let data: InstitutionalPresetData
        /// true: 保存データを読めなかった状態からの復旧（置き換え）。
        /// false: 通常の合流（id が一致するものだけ上書き）。
        let willReplace: Bool
    }

    var body: some View {
        NavigationStack {
            List {
                // 読み込みに失敗している間は保存を止めている。利用者に伝えないと、
                // 登録も編集も無言で効かなくなり、理由が分からない状態になる。
                // 一覧の先頭に置いて、操作を始める前に目に入るようにする。
                if let err = model.loadFailure {
                    Section {
                        Label {
                            Text(err)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.caption)
                    }
                }

                Section {
                    ForEach(model.presets) { p in
                        Button {
                            editing = p
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.name).foregroundStyle(.primary)
                                    if let note = p.note, !note.isEmpty {
                                        Text(note).font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                                Spacer()
                                Text(p.regimenLabel)
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(model.loadFailure != nil)
                    }
                    .onDelete { offsets in
                        // 確認を挟む。誤スワイプで消えると、手で入力した内容を
                        // 思い出して入れ直すことになる。取り消す手段はない。
                        guard let i = offsets.first else { return }
                        pendingDeletion = model.presets[i]
                    }
                    Button {
                        showAdd = true
                    } label: {
                        Label("プリセットを追加", systemImage: "plus")
                    }
                    .disabled(model.loadFailure != nil)
                } header: {
                    Text("自施設のプロトコル")
                }

                ForEach(PresetCategory.allCases) { cat in
                    Section {
                        ForEach(FractionationPresets.byCategory(cat)) { p in
                            Toggle(isOn: Binding(
                                get: { !model.hiddenBuiltInKeys.contains(p.id) },
                                set: { model.setHidden(!$0, key: p.id) }
                            )) {
                                HStack {
                                    Text(p.site)
                                    Spacer()
                                    Text(p.regimenLabel)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(model.loadFailure != nil)
                        }
                    } header: {
                        Text(cat.displayName)
                    }
                }

                Section {
                    Text("内蔵プリセットは一覧での表示を切り替えられますが、線量分割と出典は変更できません。値を書き換えると、出典を表示したまま中身が別のものになるためです。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let err = model.lastSaveError {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("プリセットの管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        // 読み込みに失敗している間は書き出さない。空の内容を書き出しても
                        // 意味がなく、それを後で読み込むと本当に空になる。
                        if model.loadFailure == nil, let data = model.exportData() {
                            ShareLink(item: data, preview: SharePreview("PocketRT のプリセット")) {
                                Label("書き出す", systemImage: "square.and.arrow.up")
                            }
                        }
                        // 保存先そのものが無いときは読み込みも出さない。読み込んでも
                        // 保存できず、「復旧できるように見える」のに実際には次回起動時
                        // 登録が失われる、という最悪の見た目になるため。書き出しボタンの
                        // 既存の扱い（loadFailure != nil で非表示）に合わせた。
                        if model.hasStore {
                            Button {
                                showImporter = true
                            } label: {
                                Label("読み込む", systemImage: "square.and.arrow.down")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .failure:
                    // SwiftUI の fileImporter は、キャンセル時にこのクロージャを呼ばない。
                    // Apple 公式ドキュメントに明示はないが、後の SDK で
                    // onCompletion:onCancellation: というキャンセル専用のオーバーロードが
                    // 追加されていることが、onCompletion がキャンセルを表現しないことの
                    // 裏付けになる。したがって .failure は iCloud 未ダウンロードなどの
                    // 本物の失敗である。
                    //
                    // ここでキャンセルを除外する判定を入れてはならない。本物の失敗が
                    // 同じエラーコードを伴った場合に、それを無言で握りつぶすことになる。
                    importMessage = String(localized: "ファイルを読み込めませんでした")
                case .success(let url):
                    guard url.startAccessingSecurityScopedResource() else {
                        importMessage = String(localized: "ファイルにアクセスできませんでした")
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    guard let data = try? Data(contentsOf: url) else {
                        importMessage = String(localized: "ファイルを読めませんでした")
                        return
                    }
                    // ここでは適用しない。他人が書き出した JSON を読み込むと、
                    // それが自施設の基準として扱われる。何が起きるかを
                    // 確認してから適用できるよう、検証だけ行って結果を
                    // 確認ダイアログに渡す。
                    switch model.previewImport(data) {
                    case .success(let preview):
                        pendingImport = PendingImport(data: preview.data, willReplace: preview.willReplace)
                    case .failure(let result):
                        presentImportResult(result)
                    }
                }
            }
            .alert("読み込み", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK") { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
            }
            .sheet(isPresented: $showAdd) {
                PresetFormView(existing: nil) { draft in
                    model.add(InstitutionalPreset(
                        id: UUID().uuidString, name: draft.name, totalDose: draft.totalDose,
                        fractions: draft.fractions, alphaBeta: draft.alphaBeta,
                        note: draft.note, createdAt: Date()))
                }
            }
            .sheet(item: $editing) { p in
                PresetFormView(existing: p) { draft in
                    model.update(InstitutionalPreset(
                        id: p.id, name: draft.name, totalDose: draft.totalDose,
                        fractions: draft.fractions, alphaBeta: draft.alphaBeta,
                        note: draft.note, createdAt: p.createdAt))
                }
            }
            .confirmationDialog(
                "このプリセットを削除しますか",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { p in
                Button("削除", role: .destructive) {
                    model.delete(id: p.id)
                    pendingDeletion = nil
                }
                Button("キャンセル", role: .cancel) { pendingDeletion = nil }
            } message: { p in
                Text("\(p.name)（\(p.regimenLabel)）を削除します。取り消せません。")
            }
            .confirmationDialog(
                "プリセットを読み込みますか",
                isPresented: Binding(
                    get: { pendingImport != nil },
                    set: { if !$0 { pendingImport = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingImport
            ) { pending in
                Button("取り込む") {
                    let result = model.applyImport(pending.data)
                    pendingImport = nil
                    presentImportResult(result)
                }
                // 「やめる」を選んだ場合、ここでは何もしない。ダイアログが閉じる
                // こと自体が「取り込まなかった」ことの合図になり、利用者が
                // 自分で選んだ結果として自明である。取り込み時のようなアラートを
                // 重ねると、「やめる」を押したのに何かが起きたように見えてしまう。
                Button("やめる", role: .cancel) { pendingImport = nil }
            } message: { pending in
                Text(importConfirmationMessage(for: pending))
            }
        }
    }

    /// 取り込みの結果をアラートで伝える。
    private func presentImportResult(_ result: ImportResult) {
        switch result {
        case .success(let added, let updated):
            importMessage = String(localized: "\(added) 件を追加、\(updated) 件を更新しました")
        case .replaced(let count):
            importMessage = String(localized: "保存データを読めなかったため、読み込んだ \(count) 件で置き換えました")
        case .unsupportedVersion:
            importMessage = String(localized: "このアプリが対応していない形式です")
        case .invalidFormat:
            importMessage = String(localized: "ファイルの形式が正しくありません")
        case .invalidPresetValues(let names):
            importMessage = String(localized: "値が範囲外のプリセットがあるため、何も取り込みませんでした: \(names.joined(separator: "、"))")
        case .storeUnavailable:
            // 通常はここに到達しない（保存先が無いときは読み込みの導線自体を
            // 出していない）。到達した場合も「復旧した」ように見せてはならない。
            importMessage = String(localized: "保存先を用意できないため、読み込んでも保存できません。")
        }
    }

    /// 取り込み前の確認ダイアログの本文。件数・合流か置き換えか・
    /// 自施設のプロトコルとして扱われることの 3 点を必ず含める。
    private func importConfirmationMessage(for pending: PendingImport) -> String {
        let count = pending.data.presets.count
        if pending.willReplace {
            return String(localized: "\(count) 件のプリセットを読み込みます。保存データを読めなかったため、既存の内容を置き換えます。読み込んだ内容は自施設のプロトコルとして扱われます。")
        } else {
            return String(localized: "\(count) 件のプリセットを読み込みます。id が一致するものは上書きされ、それ以外は追加されます。読み込んだ内容は自施設のプロトコルとして扱われます。")
        }
    }
}
