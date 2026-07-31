import SwiftUI

/// 数値入力 + 単位ラベル + バリデーション赤字
struct NumberField: View {
    let label: String
    let unit: String
    @Binding var value: String
    let error: String?

    init(label: String, unit: String, value: Binding<String>, error: String? = nil) {
        self.label = label
        self.unit = unit
        self._value = value
        self.error = error
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .frame(width: 80, alignment: .leading)
                TextField("", text: $value)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 80)
            }
        }
    }
}
