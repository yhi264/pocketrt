import SwiftUI

struct PresetSheet: View {
    let onSelect: (FractionationPreset) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(PresetCategory.allCases) { cat in
                    Section(cat.rawValue) {
                        ForEach(FractionationPresets.byCategory(cat)) { p in
                            Button {
                                onSelect(p)
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
                                    Text("出典: \(p.source) / α/β \(String(format: "%.1f", p.recommendedAlphaBeta))")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }
                Section {
                    Text("プリセットは代表的なレジメン例の参考表示です。施設プロトコル・最新ガイドラインを必ず参照してください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("プリセットから選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
