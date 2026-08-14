import Testing
@testable import PocketRT

/// 線量分割換算の画面ロジック。
///
/// 換算は BED を保つように行う。元の線量分割の BED / EQD2 を換算先の上に
/// 出すことで、一致しているかを利用者が目で確かめられるようにしている。
@Suite("線量分割換算")
struct FractionationConversionViewModelTests {

    private func makeVM() -> FractionationConversionViewModel {
        let vm = FractionationConversionViewModel()
        vm.sourceDoseText = "50"
        vm.sourceFractionsText = "25"
        vm.alphaBetaText = "3"
        vm.mode = .fractions
        vm.targetFractionsText = "10"
        return vm
    }

    @Test("元の BED と EQD2 が出る")
    func sourceBEDAndEQD2() {
        let vm = makeVM()
        // 50 Gy / 25 Fr、α/β = 3 → d = 2、BED = 50 * (1 + 2/3) = 83.333
        #expect(abs((vm.sourceBED ?? 0) - 83.3333) < 0.001)
        // EQD2 = BED / (1 + 2/3) = 50
        #expect(abs((vm.sourceEQD2 ?? 0) - 50.0) < 0.001)
    }

    @Test("元の BED は換算先の入力に依存しない")
    func sourceBEDIndependentOfTarget() {
        // 換算先を打っている途中で元の BED が消えると、何と比べているのかが
        // 分からなくなる
        let vm = makeVM()
        let before = vm.sourceBED
        vm.targetFractionsText = ""
        #expect(vm.sourceBED == before, "換算先が未入力だと元の BED が消える")
        vm.targetFractionsText = "999"          // 範囲外
        #expect(vm.sourceBED == before, "換算先が範囲外だと元の BED が消える")
        #expect(vm.result == nil, "範囲外の換算先で結果が出ている")
    }

    @Test("元の入力が不正なら BED も出ない")
    func sourceBEDRequiresValidSource() {
        let vm = makeVM()
        vm.sourceDoseText = "500"               // 0.1〜200 の範囲外
        #expect(vm.sourceBED == nil)
        #expect(vm.sourceEQD2 == nil)
    }

    @Test("分割数を指定した換算は BED を保つ")
    func fractionsModePreservesBED() {
        let vm = makeVM()
        vm.mode = .fractions
        vm.targetFractionsText = "10"
        let source = vm.sourceBED ?? 0
        let converted = vm.result?.bed ?? 0
        #expect(abs(converted - source) < 0.001, "分割数指定で BED が変わっている")
    }

    @Test("1 回線量を指定した換算は分割数の丸めで BED がずれうる")
    func dosePerFractionModeMayDifferByRounding() {
        // 情報画面が「1 回線量を指定した場合は分割数を丸めるため BED は
        // 厳密には一致しない」と説明している。元の BED を並べて出すのは、
        // その説明を数値で確かめられるようにするためでもある。
        let vm = makeVM()
        vm.mode = .dosePerFraction
        vm.targetDoseFxText = "3.0"
        let source = vm.sourceBED ?? 0
        let converted = vm.result?.bed ?? 0
        #expect(converted > 0)
        // 一致はしないが、丸め 1 回分を超えて離れることはない
        #expect(abs(converted - source) < source * 0.15,
                "丸めの範囲を超えてずれている: 元 \(source) / 換算後 \(converted)")
    }
}
