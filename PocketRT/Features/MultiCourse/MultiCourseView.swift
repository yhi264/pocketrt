import SwiftUI

struct MultiCourseView: View {
    @State private var vm = MultiCourseViewModel()
    @State private var presetTargetID: UUID?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(vm.courses.enumerated()), id: \.element.id) { idx, course in
                        courseCard(index: idx + 1, course: course)
                    }

                    if vm.canAdd {
                        Button {
                            vm.addCourse()
                        } label: {
                            Label("コースを追加", systemImage: "plus.circle")
                        }
                        .buttonStyle(.bordered)
                    }

                    ResultCard(title: "合算", isDisabled: vm.validCourses.isEmpty) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let b = vm.cumulativeBED {
                                HStack {
                                    Text("Σ BED")
                                    Spacer()
                                    GySubscript(value: b, alphaBeta: vm.commonAlphaBeta)
                                }
                            }
                            if let e = vm.cumulativeEQD2 {
                                HStack {
                                    Text("Σ EQD2")
                                    Spacer()
                                    GySubscript(value: e)
                                }
                            }
                            if vm.validCourses.isEmpty {
                                Text("有効なコースがありません")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Text("⚠ 再照射では回復係数(recovery factor)を考慮する必要があります。本計算は単純加算であり、再照射計画には用いないでください。")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.08)))
                }
                .padding()
            }
            .navigationTitle("多コース合算")
            .sheet(item: Binding(
                get: { presetTargetID.flatMap { id in vm.courses.first(where: { $0.id == id }) } },
                set: { _ in presetTargetID = nil }
            )) { target in
                PresetSheet { preset in
                    vm.apply(preset: preset, to: target)
                }
            }
            .infoToolbarButton()
        }
    }

    @ViewBuilder
    private func courseCard(index: Int, course: CourseInput) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("コース \(index)").font(.headline)
                Spacer()
                if vm.courses.count > 1 {
                    Button(role: .destructive) {
                        vm.remove(course)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                }
            }
            Button {
                presetTargetID = course.id
            } label: {
                Label("プリセット", systemImage: "list.clipboard")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            NumberField(label: "総線量", unit: "Gy", value: Binding(get: { course.totalDoseText }, set: { course.totalDoseText = $0 }))
            NumberField(label: "分割数", unit: "Fr", value: Binding(get: { course.fractionsText }, set: { course.fractionsText = $0 }))
            NumberField(label: "α/β",  unit: "Gy", value: Binding(get: { course.alphaBetaText }, set: { course.alphaBetaText = $0 }))

            if let b = course.bed, let e = course.eqd2, let ab = course.alphaBeta {
                HStack(spacing: 16) {
                    HStack { Text("BED").font(.caption); GySubscript(value: b, alphaBeta: ab, precision: 1) }
                    HStack { Text("EQD2").font(.caption); GySubscript(value: e, precision: 1) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
    }
}
