import SwiftUI

struct PresetSheet: View {
    let onSelect: (PresetSelection) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showEditor = false
    let model: PresetStoreModel

    var body: some View {
        NavigationStack {
            List {
                // 読み込みに失敗している間は presets が空のままなので、このセクションを
                // 単に消すと「まだ登録していない」のか「読めていない」のかが区別できない。
                // 計算・合算・予定の 3 タブから開く、日常的にいちばん開く画面なので、
                // 編集画面・出典一覧と同じ警告を先頭に出す。
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

                if !model.presets.isEmpty {
                    Section {
                        ForEach(model.presets) { p in
                            Button {
                                onSelect(.institutional(p))
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(p.name).foregroundStyle(.primary)
                                        Spacer()
                                        Text(p.regimenLabel)
                                            .font(.callout.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                    if let note = p.note, !note.isEmpty {
                                        Text(note).font(.caption2).foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("自施設のプロトコル")
                    }
                }

                ForEach(PresetCategory.allCases) { cat in
                    let items = model.visibleBuiltIns(category: cat)
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { p in
                                Button {
                                    onSelect(.builtIn(p))
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(p.site)
                                                .foregroundStyle(.primary)
                                            Spacer()
                                            Text(p.regimenLabel)
                                                .font(.callout.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                        }
                                        Text("出典: \(p.citations.map { String(localized: $0.shortLabel) }.joined(separator: " / ")) / α/β \(String(format: "%.1f", p.recommendedAlphaBeta))")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        if let note = p.note {
                                            Text(note)
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }
                        } header: {
                            Text(cat.displayName)
                        }
                    }
                }

                Section {
                    Text("プリセットは代表的なレジメン例の参考表示です。施設のプロトコルと最新のガイドラインを必ず参照してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("プリセットから選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("編集") { showEditor = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditor) {
                PresetEditorView(model: model)
            }
        }
    }
}
