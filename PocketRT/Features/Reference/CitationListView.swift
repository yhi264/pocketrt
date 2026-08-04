import SwiftUI

struct CitationListView: View {
    var body: some View {
        List {
            ForEach(PresetCategory.allCases) { cat in
                Section(cat.displayName) {
                    ForEach(FractionationPresets.byCategory(cat)) { p in
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
                }
            }
        }
        .navigationTitle("プリセットの出典")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 文献 1 件の表示。一次文献がある場合は書誌情報とリンク、
/// ない場合は慣用レジメンである旨を出す。
struct CitationRow: View {
    let citation: Citation

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if citation.hasPrimarySource {
                Text(citation.shortLabel)
                    .font(.caption.bold())
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
            } else {
                Text(citation.shortLabel)
                    .font(.caption.bold())
                Text(citation.unsourcedNote ?? "")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }
}
