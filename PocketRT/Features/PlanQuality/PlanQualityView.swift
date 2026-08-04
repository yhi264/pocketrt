import SwiftUI

struct PlanQualityView: View {
    @State private var vm = PlanQualityViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        Text("標的と処方").font(.headline)
                        NumberField(label: "PTV 体積", unit: "cc", value: $vm.tvText,
                                    error: vm.error(for: vm.tvText, value: vm.tv))
                        NumberField(label: "処方線量", unit: "Gy", value: $vm.rxText,
                                    error: vm.error(for: vm.rxText, value: vm.rx))
                        NumberField(label: "分割数", unit: "Fr", value: $vm.fractionsText,
                                    error: vm.fractionsText.isEmpty || vm.fractions != nil ? nil : String(localized: "正の整数を入力"))
                    }

                    Divider()

                    Group {
                        Text("等線量体積").font(.headline)
                        NumberField(label: "PIV", unit: "cc", value: $vm.pivText,
                                    error: vm.error(for: vm.pivText, value: vm.piv))
                        NumberField(label: "PTV∩PIV", unit: "cc", value: $vm.tvPIVText,
                                    error: vm.error(for: vm.tvPIVText, value: vm.tvPIV))
                        NumberField(label: "V50%", unit: "cc", value: $vm.v50Text,
                                    error: vm.error(for: vm.v50Text, value: vm.v50))
                        Text("PIV は処方線量以上を受ける全体積、PTV∩PIV は PTV のうち処方線量以上を受ける体積、V50% は処方線量の 50% 以上を受ける体積。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    Group {
                        Text("線量統計").font(.headline)
                        NumberField(label: "Dmax", unit: "Gy", value: $vm.dmaxText,
                                    error: vm.error(for: vm.dmaxText, value: vm.dmax))
                        NumberField(label: "D2%", unit: "Gy", value: $vm.d2Text,
                                    error: vm.error(for: vm.d2Text, value: vm.d2))
                        NumberField(label: "D50%", unit: "Gy", value: $vm.d50Text,
                                    error: vm.error(for: vm.d50Text, value: vm.d50))
                        NumberField(label: "D98%", unit: "Gy", value: $vm.d98Text,
                                    error: vm.error(for: vm.d98Text, value: vm.d98))
                        NumberField(label: "D2cm", unit: "Gy", value: $vm.d2cmText,
                                    error: vm.error(for: vm.d2cmText, value: vm.d2cmDose))
                    }

                    if !vm.issues.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(vm.issues, id: \.rawValue) { issue in
                                Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.red.opacity(0.1)))
                    }

                    ResultCard(title: "指標") {
                        VStack(alignment: .leading, spacing: 6) {
                            indexRow("CI (RTOG)", vm.ciRTOG, format: "%.3f")
                            indexRow("CI (Paddick)", vm.ciPaddick, format: "%.3f")
                            indexRow("HI (RTOG)", vm.hiRTOG, format: "%.3f")
                            indexRow("HI (ICRU-83)", vm.hiICRU83, format: "%.3f")
                            indexRow("R50%", vm.r50Value, format: "%.2f")
                            indexRow("GI (Paddick)", vm.giPaddick, format: "%.2f")
                            indexRow("D2cm", vm.d2cmValue, format: "%.1f", suffix: " %Rx")
                        }
                    }

                    Divider()

                    Group {
                        Text("プロトコル逸脱判定").font(.headline)
                        Picker("プロトコル", selection: $vm.selectedProtocol) {
                            ForEach(ProtocolSelection.allCases) { p in
                                Text(p.displayName).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    ResultCard(title: "判定", isDisabled: vm.judgementBlockKind == .incompleteInput) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let reason = vm.judgementBlockedReason {
                                if vm.judgementBlockKind == .outsideProtocolScope {
                                    Label(reason, systemImage: "exclamationmark.circle")
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                } else {
                                    Text(reason)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                deviationRow("R100% (= CI RTOG)", vm.r100Deviation)
                                deviationRow("R50%", vm.r50Deviation)
                                deviationRow("D2cm", vm.d2cmDeviation)
                                if let l = vm.limits {
                                    Text(String(format: "許容値: R50%% < %.2f (none) / < %.2f (minor)、D2cm < %.1f%% / < %.1f%%",
                                                l.r50None, l.r50Minor, l.d2cmNone, l.d2cmMinor))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text("出典: \(ConformityCriteria.sourceLabel)。表にない PTV 体積は原典 Note 1 に従い線形補間しています。本判定は公表された表の参照であり、推奨や指示ではありません。")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("品質指標")
            .navigationBarTitleDisplayMode(.inline)
            .infoToolbarButton()
        }
    }

    @ViewBuilder
    private func indexRow(_ label: String, _ value: Double?, format: String, suffix: String = "") -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            if let value {
                Text(String(format: format, value) + suffix)
                    .font(.body.monospacedDigit())
                    .bold()
            } else {
                Text("入力待ち")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func deviationRow(_ label: String, _ level: DeviationLevel?) -> some View {
        HStack {
            Text(label).font(.callout)
            Spacer()
            if let level {
                Text(level.displayName)
                    .font(.callout.bold())
                    .foregroundStyle(color(for: level))
            } else {
                Text("入力待ち")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func color(for level: DeviationLevel) -> Color {
        switch level {
        case .perProtocol: .green
        case .minor:       .orange
        case .major:       .red
        }
    }
}
