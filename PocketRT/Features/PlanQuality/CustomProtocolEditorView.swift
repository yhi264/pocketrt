import SwiftUI
import UniformTypeIdentifiers

/// 書き出すファイル。
///
/// **`ShareLink(item:)` に `Data` をそのまま渡してはならない。** `Data` の
/// `Transferable` 表現は content type が `public.data` で、「ファイルに保存」
/// を選ぶと拡張子の付かないファイルとして書き出される。そのファイルは
/// `.fileImporter(allowedContentTypes: [.json])` の一覧に現れないため、
/// **自分で書き出したファイルを自分で読み込めない。**書き出しと読み込みは
/// 対で意味を持つ機能であり、片道になっていては用をなさない。
///
/// content type と拡張子を明示するために `Transferable` を自前で用意する。
struct CustomProtocolExportFile: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName("pocketrt-custom-protocols.json")
    }
}

/// 自施設の判定基準（利用者定義プロトコル）の管理画面。
///
/// `PresetEditorView`（D1）に倣う。D1 は永続化まわりで 5 件の欠陥を経ており、
/// 失敗状態の出し分けはその教訓をそのまま踏襲する（仕様 §4.4）。
struct CustomProtocolEditorView: View {
    let model: CustomProtocolStoreModel
    @Environment(\.dismiss) private var dismiss
    @State private var editing: CustomProtocol?
    @State private var showAdd = false
    @State private var pendingDeletion: CustomProtocol?
    @State private var pendingDiscard = false
    @State private var showImporter = false
    @State private var importMessage: String?
    @State private var pendingImport: PendingImport?

    /// 取り込み前の確認に使う、検証済みの内容。
    private struct PendingImport {
        let data: CustomProtocolData
        /// true: `corruptedContent` からの復旧（置き換え）。
        /// false: 通常の合流（id が一致するものだけ上書き）。
        let willReplace: Bool
    }

    var body: some View {
        NavigationStack {
            List {
                // 失敗状態は種類ごとに正しい復旧手段が違う（仕様 §4.4）。
                // 画面の先頭に置き、操作を始める前に必ず目に入るようにする。
                failureSection

                Section {
                    ForEach(model.protocols) { p in
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
                                Text(thresholdSummary(p))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .disabled(isOperationDisabled)
                    }
                    .onDelete { offsets in
                        // 確認を挟む。手で入力して長く使うデータで、
                        // 誤スワイプで消えると取り消す手段がない。
                        guard let i = offsets.first else { return }
                        pendingDeletion = model.protocols[i]
                    }
                    Button {
                        showAdd = true
                    } label: {
                        Label("基準を追加", systemImage: "plus")
                    }
                    .disabled(isOperationDisabled)
                } header: {
                    Text("自施設の基準")
                }

                if let err = model.lastSaveError {
                    Section {
                        Text(err).foregroundStyle(.red).font(.caption)
                    }
                }
            }
            .navigationTitle("自施設の基準の管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 書き出しも読み込みも出せない状態（保存先が無い、データは
                // 無事だが読めない）では、メニューごと出さない。中身が空の
                // メニューを開かせると、何が使えないのかが分からない。
                if model.canExport || model.canImport {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            // exportData() は canExport を自分で確認し、
                            // 満たさなければ nil を返す。
                            if let data = model.exportData() {
                                ShareLink(
                                    item: CustomProtocolExportFile(data: data),
                                    preview: SharePreview("PocketRT の自施設基準")
                                ) {
                                    Label("書き出す", systemImage: "square.and.arrow.up")
                                }
                            }
                            if model.canImport {
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
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                switch result {
                case .failure:
                    // SwiftUI の fileImporter は、キャンセル時にこのクロージャを
                    // 呼ばない（後の SDK に onCancellation: が別途追加されたことが
                    // その裏付けになる）。したがって .failure は iCloud 未ダウンロード
                    // などの本物の失敗である。ここでキャンセルを除外する判定を
                    // 入れてはならない。本物の失敗を無言で握りつぶすことになる。
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
                    // それが自施設の基準として判定に使われる。判定パネルには
                    // 「利用者が登録した基準による」と出たまま、実際には別の
                    // 施設の基準で判定することになる。何が起きるかを確認して
                    // から適用できるよう、検証だけ行って結果を確認ダイアログに渡す。
                    switch model.previewImport(data) {
                    case .success(let preview):
                        pendingImport = PendingImport(
                            data: preview.data, willReplace: preview.willReplace)
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
            .confirmationDialog(
                "基準を読み込みますか",
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
                // 「やめる」で何も出さない。ダイアログが閉じること自体が
                // 「取り込まなかった」合図であり、利用者が自分で選んだ結果と
                // して自明である。ここでアラートを重ねると、やめたのに何かが
                // 起きたように見える。
                Button("やめる", role: .cancel) { pendingImport = nil }
            } message: { pending in
                Text(importConfirmationMessage(for: pending))
            }
            .sheet(isPresented: $showAdd) {
                CustomProtocolFormView(existing: nil) { draft in
                    model.add(CustomProtocol(
                        id: UUID().uuidString, name: draft.name, note: draft.note,
                        thresholds: draft.thresholds, createdAt: Date()))
                }
            }
            .sheet(item: $editing) { p in
                CustomProtocolFormView(existing: p) { draft in
                    model.update(CustomProtocol(
                        id: p.id, name: draft.name, note: draft.note,
                        thresholds: draft.thresholds, createdAt: p.createdAt))
                }
            }
            .confirmationDialog(
                "この基準を削除しますか",
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
                Text("\(p.name) を削除します。取り消せません。")
            }
            .confirmationDialog(
                "保存データを破棄しますか",
                isPresented: $pendingDiscard,
                titleVisibility: .visible
            ) {
                Button("破棄", role: .destructive) {
                    model.discardCorruptedData()
                    pendingDiscard = false
                }
                Button("キャンセル", role: .cancel) { pendingDiscard = false }
            } message: {
                // 何が失われるか（読めなくなった保存データ）と、取り消せないことを
                // 明示する。削除の確認と同じ形にする（team-lead 指示）。
                Text("読めなくなった保存データを破棄し、空の状態から登録し直します。取り消せません。")
            }
        }
    }

    /// 失敗状態を先頭に出す。状態ごとに復旧手段が違う（仕様 §4.4）。
    ///
    /// - `hasStore == false`: 保存先そのものが無い。警告のみで、読み込みを
    ///   含め何も導線を出さない（読み直す先が無い）
    /// - `.unreadableFile`: データは無事（権限・I/O 障害で一時的に開けない
    ///   だけ）。再読み込みの導線を出す
    /// - `.unsupportedSchemaVersion`: データは無事で、ただ新しい形式なだけ。
    ///   **再読み込みも破棄も出さない。** 破棄を出すと、アプリを更新すれば
    ///   読めたはずのデータを利用者自身の手で消させることになる
    ///   （仕様 §4.4「この 1 点だけは絶対に間違えないこと」）
    /// - `.corruptedContent`: 二度と読めないので、破棄して作り直す導線を出す
    @ViewBuilder
    private var failureSection: some View {
        if !model.hasStore {
            Section {
                warningLabel(model.loadFailure ?? "")
            }
        } else if let kind = model.loadFailureKind {
            Section {
                warningLabel(model.loadFailure ?? "")
                switch kind {
                case .unreadableFile:
                    Button("再読み込み") { model.reload() }
                case .unsupportedSchemaVersion:
                    EmptyView()
                case .corruptedContent:
                    // 読み込みを先に出す。破棄は登録を失うが、読み込みは
                    // 書き出しておいた内容を取り戻せる。失うものが少ない順に並べる。
                    Button("書き出したファイルから読み込む") { showImporter = true }
                    Button("保存データを破棄", role: .destructive) { pendingDiscard = true }
                }
            }
        }
    }

    @ViewBuilder
    private func warningLabel(_ message: String) -> some View {
        Label {
            Text(message)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .font(.caption)
    }

    /// `hasStore == false` でも `loadFailure != nil`（`.custom` 系のどの失敗でも）
    /// でも、読み込みを含めすべての変更操作を止める。`persist()` 自体は
    /// 呼んでも何もしない作りだが、利用者に「保存できているように見えて
    /// 実は保存されない」ボタンを触らせないため、ここで無効化する。
    private var isOperationDisabled: Bool {
        !model.hasStore || model.loadFailure != nil
    }

    /// 取り込みの結果をアラートで伝える。
    private func presentImportResult(_ result: CustomProtocolImportResult) {
        switch result {
        case .success(let added, let updated):
            importMessage = String(localized: "\(added) 件を追加、\(updated) 件を更新しました")
        case .replaced(let count):
            importMessage = String(localized: "保存データを読めなかったため、読み込んだ \(count) 件で置き換えました")
        case .unsupportedVersion:
            importMessage = String(localized: "このアプリが対応していない形式です")
        case .invalidFormat:
            importMessage = String(localized: "ファイルの形式が正しくありません")
        case .invalidProtocolValues(let names):
            importMessage = String(localized: "値が範囲外の基準があるため、何も取り込みませんでした: \(names.joined(separator: "、"))")
        case .storeUnavailable:
            // 通常はここに到達しない（保存先が無いときは読み込みの導線自体を
            // 出していない）。到達した場合も「復旧した」ように見せてはならない。
            importMessage = String(localized: "保存先を用意できないため、読み込んでも保存できません。")
        case .blockedByIntactData(let kind):
            // データが無事なまま読めていない状態。置き換えると無事なものを失う。
            // 何が使えないかではなく、先に何をすべきかを伝える。
            switch kind {
            case .unreadableFile:
                importMessage = String(localized: "保存データは端末に残っています。先に「再読み込み」をお試しください。読み込んで置き換えると、読めるようになったはずの登録を失います。")
            case .unsupportedSchemaVersion:
                importMessage = String(localized: "保存データは新しい形式のまま残っています。アプリを更新すると読めます。読み込んで置き換えると、その登録を失います。")
            case .corruptedContent:
                // この種別は読み込みを許す状態なので、ここには到達しない。
                importMessage = String(localized: "読み込めませんでした")
            }
        case .blockedByUnknownFailure:
            importMessage = String(localized: "保存データを読めない原因を特定できていません。読み込んで置き換えると、残っているかもしれない登録を失います。アプリを再起動してからお試しください。")
        }
    }

    /// 取り込み前の確認ダイアログの本文。件数・合流か置き換えか・
    /// 自施設の基準として判定に使われることの 3 点を必ず含める。
    ///
    /// D1（プリセット）の文言に「判定に使われます」を足してある。プリセットは
    /// 計算の入力値だが、判定基準は「基準内 / 基準を超える」という臨床的な
    /// 言明を直接生む。他施設の基準を取り込んだことを忘れたまま使う害が大きい。
    private func importConfirmationMessage(for pending: PendingImport) -> String {
        let count = pending.data.protocols.count
        if pending.willReplace {
            return String(localized: "\(count) 件の基準を読み込みます。保存データを読めなかったため、既存の内容を置き換えます。読み込んだ内容は自施設の基準として扱われ、判定に使われます。")
        } else {
            return String(localized: "\(count) 件の基準を読み込みます。id が一致するものは上書きされ、それ以外は追加されます。読み込んだ内容は自施設の基準として扱われ、判定に使われます。")
        }
    }

    /// 一覧の 1 行に出す閾値の要約。「R100% 1.20 / R50% 4.50」のように、
    /// 定めている指標だけを並べる。
    private func thresholdSummary(_ p: CustomProtocol) -> String {
        MetricKey.allCases.compactMap { key -> String? in
            guard let t = p.thresholds[key] else { return nil }
            return "\(key.displayName) \(DoseFormat.plainString(t.within))"
        }.joined(separator: " / ")
    }
}

/// 自施設の判定基準の入力フォーム。追加と編集の両方に使う。
struct CustomProtocolFormView: View {
    let existing: CustomProtocol?
    let onSave: (CustomProtocolDraft) -> Void

    @State private var name = ""
    @State private var note = ""
    @State private var r100Within = ""
    @State private var r100Tolerated = ""
    @State private var r50Within = ""
    @State private var r50Tolerated = ""
    @State private var d2cmWithin = ""
    @State private var d2cmTolerated = ""
    @State private var error: CustomProtocolValidationError?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // 名前・メモ・「閾値が 1 つも無い」に関するエラーは特定の指標欄を
                // 指さないので、先頭にまとめて出す。指標ごとのエラー
                // （範囲外・許容だけ・許容が基準内以下）は各行に出す
                // （bannerMessage / fieldErrorMessage(for:) で排他的に振り分ける）。
                if let bannerMessage {
                    Section {
                        Label {
                            Text(bannerMessage)
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .font(.callout)
                    }
                }

                Section {
                    TextField("名前", text: $name)
                    TextField("メモ（任意）", text: $note, axis: .vertical)
                } header: {
                    Text("基本情報")
                }

                Section {
                    metricRow(.r100, within: $r100Within, tolerated: $r100Tolerated)
                    metricRow(.r50, within: $r50Within, tolerated: $r50Tolerated)
                    metricRow(.d2cm, within: $d2cmWithin, tolerated: $d2cmTolerated)
                } header: {
                    Text("閾値")
                } footer: {
                    Text("「基準内」未満なら基準内、「許容」未満なら基準をやや超える、それ以上は基準を超える。「許容」は空欄にできます（2 段階になります）。定めていない指標は両方空欄のままにしてください。少なくとも 1 つの指標に「基準内」の入力が必要です。")
                }
            }
            .navigationTitle(existing == nil ? "基準を追加" : "基準を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                }
            }
            .onAppear(perform: load)
        }
    }

    /// 指標 1 行。「基準内」「許容」の 2 欄と、その指標を指すエラーだけを出す。
    ///
    /// `NumberField` を使わないのは、`NumberField` が 1 欄に 1 つのエラーを
    /// 想定した作りで、ここは 1 指標に 2 欄（基準内・許容）が並ぶため。
    /// エラーは指標単位（`CustomProtocolValidationError` が指標を指す）なので、
    /// 2 欄の下にまとめて 1 つ出す。
    @ViewBuilder
    private func metricRow(_ key: MetricKey, within: Binding<String>, tolerated: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(key.displayName)
                    .layoutPriority(1)
                    .frame(minWidth: 56, alignment: .leading)
                TextField("基準内", text: within)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(Text("\(key.displayName) 基準内"))
                TextField("許容", text: tolerated)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(Text("\(key.displayName) 許容"))
                Text(key.unitLabel)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            if let message = fieldErrorMessage(for: key) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    /// 名前・メモ・「閾値が 1 つも無い」に関するエラーの文言。指標を指す
    /// エラーはここに含めない（`fieldErrorMessage(for:)` 側に出す）。
    private var bannerMessage: String? {
        guard let error else { return nil }
        switch error {
        case .nameEmpty, .nameTooLong, .noteTooLong, .noThresholds:
            return String(localized: error.message)
        case .thresholdOutOfRange, .toleratedWithoutWithin, .toleratedNotGreaterThanWithin:
            return nil
        }
    }

    /// 指定した指標を指すエラーの文言。指さないエラー（名前・メモ等）は nil。
    private func fieldErrorMessage(for key: MetricKey) -> String? {
        guard let error else { return nil }
        switch error {
        case .thresholdOutOfRange(let k), .toleratedWithoutWithin(let k), .toleratedNotGreaterThanWithin(let k):
            return k == key ? String(localized: error.message) : nil
        case .nameEmpty, .nameTooLong, .noteTooLong, .noThresholds:
            return nil
        }
    }

    private func load() {
        guard let e = existing else { return }
        name = e.name
        note = e.note ?? ""
        if let t = e.thresholds[.r100] {
            r100Within = DoseFormat.plainString(t.within)
            r100Tolerated = t.tolerated.map(DoseFormat.plainString) ?? ""
        }
        if let t = e.thresholds[.r50] {
            r50Within = DoseFormat.plainString(t.within)
            r50Tolerated = t.tolerated.map(DoseFormat.plainString) ?? ""
        }
        if let t = e.thresholds[.d2cm] {
            d2cmWithin = DoseFormat.plainString(t.within)
            d2cmTolerated = t.tolerated.map(DoseFormat.plainString) ?? ""
        }
    }

    private func save() {
        let thresholds: [MetricKey: MetricThresholdInput] = [
            .r100: MetricThresholdInput(within: r100Within, tolerated: r100Tolerated),
            .r50: MetricThresholdInput(within: r50Within, tolerated: r50Tolerated),
            .d2cm: MetricThresholdInput(within: d2cmWithin, tolerated: d2cmTolerated)
        ]
        switch CustomProtocolValidator.validate(name: name, note: note, thresholds: thresholds) {
        case .success(let draft):
            error = nil
            onSave(draft)
            dismiss()
        case .failure(let e):
            error = e
        }
    }
}
