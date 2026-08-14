import SwiftUI

/// 自施設プリセットの入力フォーム。追加と編集の両方に使う。
struct PresetFormView: View {
    let existing: InstitutionalPreset?
    let onSave: (InstitutionalPresetDraft) -> Void

    @State private var name = ""
    @State private var totalDose = ""
    @State private var fractions = ""
    @State private var alphaBeta = ""
    @State private var note = ""
    @State private var error: PresetValidationError?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if let error {
                    Section {
                        Label {
                            Text(error.message)
                        } icon: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .font(.callout)
                    }
                }

                Section {
                    TextField("名前", text: $name)
                    HStack {
                        TextField("総線量", text: $totalDose).keyboardType(.decimalPad)
                        Text("Gy").foregroundStyle(.secondary)
                    }
                    HStack {
                        TextField("分割数", text: $fractions).keyboardType(.numberPad)
                        Text("Fr").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("線量分割")
                }

                Section {
                    HStack {
                        TextField("α/β（任意）", text: $alphaBeta).keyboardType(.decimalPad)
                        Text("Gy").foregroundStyle(.secondary)
                    }
                } header: {
                    Text("α/β")
                } footer: {
                    Text("空欄にすると、このプリセットを選んでも α/β を変更しません。プロトコルが α/β を定めていない場合は空欄にしてください。")
                }

                Section {
                    TextField("メモ（任意）", text: $note, axis: .vertical)
                } footer: {
                    Text("同時併用化療の有無など、線量分割だけでは表せない条件を書けます。")
                }
            }
            .navigationTitle(existing == nil ? "プリセットを追加" : "プリセットを編集")
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

    private func load() {
        guard let e = existing else { return }
        name = e.name
        totalDose = DoseFormat.doseString(e.totalDose)
        fractions = "\(e.fractions)"
        if let ab = e.alphaBeta {
            alphaBeta = DoseFormat.alphaBetaString(ab)
        }
        note = e.note ?? ""
    }

    private func save() {
        switch PresetValidator.validate(name: name, totalDose: totalDose,
                                        fractions: fractions, alphaBeta: alphaBeta, note: note) {
        case .success(let draft):
            error = nil
            onSave(draft)
            dismiss()
        case .failure(let e):
            error = e
        }
    }
}
