import Testing
import Foundation
@testable import PocketRT

@Suite("合算タブ")
struct MultiCourseViewModelTests {

    private func institutional(alphaBeta: Double?) -> InstitutionalPreset {
        InstitutionalPreset(id: "i1", name: "自施設 前立腺", totalDose: 60.0,
                            fractions: 20, alphaBeta: alphaBeta, note: nil,
                            createdAt: Date(timeIntervalSince1970: 0))
    }

    // MARK: - α/β は画面に 1 つ

    @Test("α/β は画面に 1 つで、全コースに効く")
    func alphaBetaIsSharedAcrossCourses() {
        let vm = MultiCourseViewModel()
        vm.alphaBetaText = "3"
        // 60 Gy/30 Fr（d=2）と 30 Gy/10 Fr（d=3）を α/β 3 で評価する
        // BED = 60×(1+2/3) + 30×(1+3/3) = 100 + 60 = 160
        #expect(vm.cumulativeBED.map { ($0 * 100).rounded() / 100 } == 160.0)
    }

    @Test("α/β を変えると合算結果が変わる")
    func changingAlphaBetaChangesTheSum() {
        let vm = MultiCourseViewModel()
        vm.alphaBetaText = "10"
        let at10 = vm.cumulativeBED
        vm.alphaBetaText = "3"
        let at3 = vm.cumulativeBED
        #expect(at10 != nil && at3 != nil)
        #expect(at10 != at3, "α/β は評価対象を決める値であり、結果を変えなければならない")
    }

    @Test("α/β が範囲外なら合算しない")
    func noSumWithoutValidAlphaBeta() {
        let vm = MultiCourseViewModel()
        vm.alphaBetaText = "0"
        #expect(vm.alphaBeta == nil)
        #expect(vm.alphaBetaError != nil, "範囲外であることを画面に出さなければならない")
        #expect(vm.cumulativeBED == nil, "評価対象が定まらないまま数字を出してはならない")
        #expect(vm.cumulativeEQD2 == nil)
        #expect(!vm.canSum)
    }

    @Test("α/β が空欄のときは誤りとして出さない（入力途中）")
    func emptyAlphaBetaIsNotAnError() {
        let vm = MultiCourseViewModel()
        vm.alphaBetaText = ""
        #expect(vm.alphaBetaError == nil)
        #expect(vm.cumulativeBED == nil)
    }

    // MARK: - プリセットの適用

    @Test("プリセットは線量と分割数だけを入れる")
    func applyBuiltInSetsDoseAndFractionsOnly() {
        let vm = MultiCourseViewModel()
        vm.alphaBetaText = "10"
        let course = vm.courses[0]
        let p = FractionationPresets.all.first { $0.id == "hypo_prostate_moderate" }!
        vm.apply(.builtIn(p), to: course)
        #expect(course.totalDoseText == "60")
        #expect(course.fractionsText == "20")
    }

    @Test("プリセットを当てても画面の α/β は変わらない")
    func applyDoesNotTouchSharedAlphaBeta() {
        let vm = MultiCourseViewModel()
        vm.alphaBetaText = "10"
        // α/β 1.5 を持つ内蔵プリセット（前立腺）を当てる
        let p = FractionationPresets.all.first { $0.id == "hypo_prostate_moderate" }!
        vm.apply(.builtIn(p), to: vm.courses[0])
        #expect(vm.alphaBetaText == "10",
                "コースへの操作で、他のコースの評価基準まで黙って変わってはならない")
    }

    @Test("α/β を持つ自施設プリセットでも画面の α/β は変わらない")
    func institutionalPresetDoesNotTouchSharedAlphaBeta() {
        let vm = MultiCourseViewModel()
        vm.alphaBetaText = "10"
        vm.apply(.institutional(institutional(alphaBeta: 1.5)), to: vm.courses[0])
        #expect(vm.alphaBetaText == "10")
        #expect(vm.courses[0].totalDoseText == "60")
        #expect(vm.courses[0].fractionsText == "20")
    }

    // MARK: - コースの増減

    @Test("コースは 3 つまで")
    func maxThreeCourses() {
        let vm = MultiCourseViewModel()
        #expect(vm.courses.count == 2)
        vm.addCourse()
        #expect(vm.courses.count == 3)
        #expect(!vm.canAdd)
        vm.addCourse()
        #expect(vm.courses.count == 3, "上限を超えて増えてはならない")
    }
}
