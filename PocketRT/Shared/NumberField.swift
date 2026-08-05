import SwiftUI

/// 数値入力 + 単位ラベル + バリデーション赤字
struct NumberField: View {
    let label: LocalizedStringKey
    let unit: LocalizedStringKey
    @Binding var value: String
    let error: String?

    init(label: LocalizedStringKey, unit: LocalizedStringKey, value: Binding<String>, error: String? = nil) {
        self.label = label
        self.unit = unit
        self._value = value
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .layoutPriority(1)
                TextField("", text: $value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel(Text(label))
                    .accessibilityHint(error ?? "")
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
