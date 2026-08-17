import SwiftUI

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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
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
