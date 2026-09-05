import SwiftUI

struct FractionationConversionView: View {
    @State private var vm = FractionationConversionViewModel()

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

                        // 換算は BED を保つように行う。元の値をここに出しておくと、
                        // 換算後と一致しているかを目で確かめられる。1 回線量を
                        // 指定した場合は分割数を丸めるため厳密には一致しないので、
                        // そのずれもここに現れる。
                        if let bed = vm.sourceBED, let eqd2 = vm.sourceEQD2, let ab = vm.alphaBeta {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("BED")
                                    Spacer()
                                    GySubscript(value: bed, alphaBeta: ab)
                                }
                                HStack {
                                    Text("EQD2")
                                    Spacer()
                                    GySubscript(value: eqd2)
                                }
                            }
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                        }
                    }

                    Divider()

                    Group {
                        Text("換算後の分割").font(.headline)
                        Picker("方式", selection: $vm.mode) {
                            Text("分割数指定").tag(FractionationConversionMode.fractions)
                            Text("1回線量指定").tag(FractionationConversionMode.dosePerFraction)
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
            .navigationTitle("線量分割換算")
            .dismissibleKeyboard()
            .infoToolbarButton()
        }
    }
}
