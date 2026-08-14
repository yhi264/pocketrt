import SwiftUI

struct SimpleCalcView: View {
    @State private var vm = SimpleCalcViewModel()
    @State private var showPresetSheet = false
    @State private var showFormula = false
    @Environment(PresetStoreModel.self) private var presetStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        showPresetSheet = true
                    } label: {
                        Label("プリセットから選ぶ", systemImage: "list.clipboard")
                    }
                    .buttonStyle(.bordered)

                    Divider()

                    NumberField(label: "総線量", unit: "Gy", value: $vm.totalDoseText, error: vm.totalDoseError)
                    NumberField(label: "分割数", unit: "Fr", value: $vm.fractionsText, error: vm.fractionsError)
                    NumberField(label: "α/β",  unit: "Gy", value: $vm.alphaBetaText, error: vm.alphaBetaError)
                    HStack {
                        Spacer()
                        AlphaBetaPicker(value: $vm.alphaBetaText)
                    }

                    ResultCard(title: "結果", isDisabled: !vm.isValid) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let d = vm.dosePerFraction {
                                HStack {
                                    Text("1回線量")
                                    Spacer()
                                    Text(String(format: "%.2f Gy", d))
                                        .font(.body.monospacedDigit())
                                }
                            }
                            if let b = vm.bed, let ab = vm.alphaBeta {
                                HStack {
                                    Text("BED")
                                    Spacer()
                                    GySubscript(value: b, alphaBeta: ab)
                                }
                            }
                            if let e = vm.eqd2 {
                                HStack {
                                    Text("EQD2")
                                    Spacer()
                                    GySubscript(value: e)
                                }
                            }
                            if !vm.isValid {
                                Text("入力を確認してください")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !vm.activeCitations.isEmpty {
                                Divider()
                                HStack(spacing: 4) {
                                    Image(systemName: "text.book.closed")
                                        .font(.caption2)
                                    Text("線量分割の出典: \(vm.activeCitations.map(\.shortLabel).joined(separator: " / "))")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.secondary)
                            }
                            if let name = vm.activeInstitutionalName {
                                Text("自施設のプロトコル: \(name)")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    DisclosureGroup("計算式を見る", isExpanded: $showFormula) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("BED = n · d · (1 + d / (α/β))")
                            Text("EQD2 = BED / (1 + 2 / (α/β))")
                            Text("d = D / n")
                        }
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationTitle("単純計算")
            .sheet(isPresented: $showPresetSheet) {
                PresetSheet(onSelect: { selection in
                    vm.apply(selection)
                }, model: presetStore)
            }
            .infoToolbarButton()
        }
    }
}
