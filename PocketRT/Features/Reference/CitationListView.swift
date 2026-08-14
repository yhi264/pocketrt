import SwiftUI

struct CitationListView: View {
    @Environment(PresetStoreModel.self) private var model

    var body: some View {
        List {
            // 読み込みに失敗しているときは、自施設プリセットが 0 件なのか
            // 読めていないだけなのかを区別できるようにする。この画面は
            // アプリが何を根拠にしているかを確かめる場所なので、
            // 「登録がない」と「読めていない」を同じ見た目にしてはならない。
            if let err = model.loadFailure {
                Section {
                    Label {
                        Text(err)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                } header: {
                    Text("自施設のプロトコル")
                }
            } else if !model.presets.isEmpty {
                Section {
                    ForEach(model.presets) { p in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(p.name)
                                Spacer()
                                Text(p.regimenLabel)
                                    .font(.callout.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Text("出典なし。利用者が登録")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 2)
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
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(p.site)
                                    Spacer()
                                    Text(p.regimenLabel)
                                        .font(.callout.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                // 1 つのレジメンが複数の試験に依拠することがある
                                // （例: 食道癌 60/30 は JCOG0303 と JCOG0909）。
                                // それぞれに書誌情報とリンクを出す。
                                ForEach(p.citations) { c in
                                    CitationRow(citation: c)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text(cat.displayName)
                    }
                }
            }

            // 品質タブの逸脱判定は「Per protocol / Minor / Major」という、
            // プリセットの表示より強い臨床的な言明をする。この画面はアプリが
            // 何を根拠にしているかを確かめる場所なので、判定の根拠もここで
            // 確認できなければならない。プリセットの出典とは節を分ける。
            Section {
                Text(ConformityCriteria.provenanceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Citations.conformity) { c in
                    CitationRow(citation: c)
                        .padding(.vertical, 2)
                }

                Text(ConformityCriteria.scopeNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                // 原典の一方の記述と計算方法が異なる。0915 の本文どおりに
                // R50% を求めた人はアプリと違う数値を得るので、必ず伝える。
                Text(ConformityCriteria.r50DefinitionNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(ConformityCriteria.correctionNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text("表にない PTV 体積は、原典 Note 1「For values of PTV dimension or volume not specified, linear interpolation between table entries is required.」に従って線形補間します。表の範囲（1.8〜163.0 cc）の外では原典に規定がないため、外挿せず判定しません。")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("品質指標の逸脱判定")
            }
        }
        .navigationTitle("出典")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 文献 1 件の表示。一次文献がある場合は書誌情報とリンク、
/// ない場合は慣用レジメンである旨を出す。
struct CitationRow: View {
    let citation: Citation

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(citation.shortLabel)
                .font(.caption.bold())
            switch citation.kind {
            case .primary:
                Text(citation.formattedReference)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    if let pmid = citation.pmid {
                        Text("PMID \(pmid)").font(.caption2).foregroundStyle(.tertiary)
                    }
                    if let url = citation.url {
                        Link("開く", destination: url).font(.caption2)
                    }
                }
            case .guideline:
                // ガイドラインは確かめられる出典なので、オレンジ（根拠不明の印）にしない
                if let note = citation.guidelineNote {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            case .unsourced:
                if let note = citation.unsourcedNote {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}
