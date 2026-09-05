import SwiftUI

struct CitationListView: View {
    @Environment(PresetStoreModel.self) private var model
    @Environment(CustomProtocolStoreModel.self) private var customProtocolStoreModel

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
            //
            // 自施設の基準（利用者定義）を先に、公表プロトコルの表を後に置く
            // （上のプリセット節、PlanQualityView のプルダウンと同じ順）。
            // loadFailure は hasStore == false（保存先が無い）のときも
            // 立つので、同じ分岐でどちらも「登録が 0 件」ではなく
            // 「確認できない」ことを示せる。「登録が無い」と「読めていない」
            // を同じ見た目にしてはならない（プリセット節と同じ理由）。
            if let err = customProtocolStoreModel.loadFailure {
                Section {
                    Label {
                        Text(err)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.caption)
                } header: {
                    Text("品質指標の逸脱判定（自施設の基準）")
                }
            } else if !customProtocolStoreModel.protocols.isEmpty {
                Section {
                    ForEach(customProtocolStoreModel.protocols) { p in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.name)
                            Text("出典なし。利用者が登録")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("品質指標の逸脱判定（自施設の基準）")
                }
            }

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

            // 頭部定位照射（Shaw 1993）は肺 SBRT（RTOG 0813 / 0915、上の節）とは
            // 判定基準の由来が違う。上の節の provenanceNote は「論文はこの表そのものを
            // 含まない」と述べており、Shaw 1993（論文本文に判定基準がある）に
            // そのまま当てはめると誤りになる。節を分けて注記も別にする
            // （頭部定位照射の設計文書に記録）。
            Section {
                Text(ConformityCriteria.cranialProvenanceNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Citations.cranialConformity) { c in
                    CitationRow(citation: c)
                        .padding(.vertical, 2)
                }

                // 判定パネルでは常時表示/折りたたみに分けている 2 つの注記
                // （`cranialJudgesTwoOfThreeNote` / `cranialCoverageDetailNote`）だが、
                // この画面は出典・根拠をまとめて確認する場所なので分けずに続けて示す。
                Text(ConformityCriteria.cranialJudgesTwoOfThreeNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(ConformityCriteria.cranialCoverageDetailNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(ConformityCriteria.cranialBoundarySafetyNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(ConformityCriteria.cranialEraNote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } header: {
                Text("品質指標の逸脱判定（頭部定位照射）")
            }

            // GI (Paddick) の但し書きの根拠。上の節（判定基準の出典）とは役割が違う
            // ため節を分ける。TROG SRS Technical Working Group は判定の根拠ではなく、
            // 指標の限界についての根拠である。混ぜると「頭部定位照射の判定基準の
            // 出典」に見えてしまい、Shaw 1993 と混同される（仕様 §2.5）。
            Section {
                Text(ConformityCriteria.giCaveatNote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(Citations.cranialLimitations) { c in
                    CitationRow(citation: c)
                        .padding(.vertical, 2)
                }
            } header: {
                Text("指標の限界（頭部定位照射・GI）")
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
