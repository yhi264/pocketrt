import SwiftUI

/// α/β プリセットから値を選ぶ Menu
struct AlphaBetaPicker: View {
    @Binding var value: String

    var body: some View {
        Menu {
            ForEach(AlphaBetaPresets.all) { preset in
                Button {
                    value = preset.value == preset.value.rounded()
                        ? String(format: "%.0f", preset.value)
                        : String(format: "%.1f", preset.value)
                } label: {
                    HStack {
                        Text(preset.label)
                        Spacer()
                        Text(String(format: "%.1f", preset.value))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } label: {
            Label("α/β プリセット", systemImage: "list.bullet")
                .font(.caption)
        }
    }
}
