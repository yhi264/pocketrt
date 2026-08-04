import SwiftUI

struct OARConversionView: View {
    @State private var vm = OARConversionViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    Group {
                        Text("元の制約").font(.headline)
                        NumberField(label: "線量",   unit: "Gy", value: $vm.sourceDoseText,      error: vm.sourceDoseError)
                        NumberField(label: "分割数", unit: "Fr", value: $vm.sourceFractionsText, error: vm.sourceFractionsError)
                        NumberField(label: "α/β",  unit: "Gy", value: $vm.alphaBetaText,       error: vm.alphaBetaError)
                        HStack {
                            Spacer()
                            AlphaBetaPicker(value: $vm.alphaBetaText)
                        }
                    }

                    Divider()

                    Group {
                        Text("換算後の分割").font(.headline)
                        Picker("方式", selection: $vm.mode) {
                            Text("分割数指定").tag(OARConversionMode.fractions)
                            Text("1回線量指定").tag(OARConversionMode.dosePerFraction)
                        }
                        .pickerStyle(.segmented)

                        switch vm.mode {
                        case .fractions:
                            NumberField(label: "分割数", unit: "Fr", value: $vm.targetFractionsText, error: vm.targetError)
                        case .dosePerFraction:
                            NumberField(label: "1回線量", unit: "Gy", value: $vm.targetDoseFxText, error: vm.targetError)
                        }
                    }

                    ResultCard(title: "換算結果", isDisabled: !vm.isValid) {
                        if let r = vm.result, let ab = vm.alphaBeta {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("総線量")
                                    Spacer()
                                    Text(String(format: "%.2f Gy", r.totalDose)).font(.body.monospacedDigit())
                                }
                                HStack {
                                    Text("1回線量")
                                    Spacer()
                                    Text(String(format: "%.2f Gy", r.dosePerFraction)).font(.body.monospacedDigit())
                                }
                                HStack {
                                    Text("分割数")
                                    Spacer()
                                    Text("\(r.fractions) Fr").font(.body.monospacedDigit())
                                }
                                Divider()
                                HStack {
                                    Text("BED")
                                    Spacer()
                                    GySubscript(value: r.bed, alphaBeta: ab)
                                }
                                HStack {
                                    Text("EQD2")
                                    Spacer()
                                    GySubscript(value: r.eqd2)
                                }
                            }
                        } else {
                            Text("入力を確認してください").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("OAR制約換算")
            .infoToolbarButton()
        }
    }
}
