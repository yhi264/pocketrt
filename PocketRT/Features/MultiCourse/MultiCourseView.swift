import SwiftUI

struct MultiCourseView: View {
    @State private var vm = MultiCourseViewModel()
    @State private var presetTargetID: UUID?
    @Environment(PresetStoreModel.self) private var presetStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // α/β は画面に 1 つだけ置く。合算が意味を持つのは評価対象の
                    // 組織を 1 つ決めたときだけで、α/β はコースではなくその
                    // 評価対象に属する。
                    VStack(alignment: .leading, spacing: 8) {
                        Text("評価する組織").font(.headline)
                        NumberField(label: "α/β", unit: "Gy",
                                    value: $vm.alphaBetaText, error: vm.alphaBetaError)
                        HStack {
                            Spacer()
                            AlphaBetaPicker(value: $vm.alphaBetaText)
                        }
                        Text("すべてのコースをこの α/β で評価します。BED は組織ごとの量なので、コースごとに変えた値を足しても、その和が生物効果を表す組織はありません。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))

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

                    ResultCard(title: "合算", isDisabled: !vm.canSum) {
                        VStack(alignment: .leading, spacing: 8) {
                            // α/β が画面で 1 つに定まっているので、添字は常に出せる。
                            // 以前はコースごとに α/β を持てたため、値が食い違うと
                            // 添字を落として表示していた。数字だけが残り、何の
                            // 組織に対する値なのか分からないまま読まれうる形だった。
                            if let b = vm.cumulativeBED, let ab = vm.alphaBeta {
                                HStack {
                                    Text("Σ BED")
                                    Spacer()
                                    GySubscript(value: b, alphaBeta: ab)
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
                            } else if vm.alphaBeta == nil {
                                Text("評価する組織の α/β を入力してください")
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
            .dismissibleKeyboard()
            .sheet(item: Binding(
                get: { presetTargetID.flatMap { id in vm.courses.first(where: { $0.id == id }) } },
                set: { _ in presetTargetID = nil }
            )) { target in
                PresetSheet(onSelect: { selection in
                    vm.apply(selection, to: target)
                }, model: presetStore)
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

            if let ab = vm.alphaBeta, let b = course.bed(alphaBeta: ab), let e = course.eqd2(alphaBeta: ab) {
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
