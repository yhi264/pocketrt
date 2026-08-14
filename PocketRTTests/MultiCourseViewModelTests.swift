import Testing
import Foundation
@testable import PocketRT

@Suite("合算タブへのプリセット適用")
struct MultiCourseViewModelTests {

    private func institutional(alphaBeta: Double?) -> InstitutionalPreset {
        InstitutionalPreset(id: "i1", name: "自施設 前立腺", totalDose: 60.0,
                            fractions: 20, alphaBeta: alphaBeta, note: nil,
                            createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test("内蔵プリセットを適用すると線量・分割数・α/β が入る")
    func applyBuiltIn() {
        let vm = MultiCourseViewModel()
        let course = vm.courses[0]
        let p = FractionationPresets.all.first { $0.id == "hypo_prostate_moderate" }!
        vm.apply(.builtIn(p), to: course)
        #expect(course.totalDoseText == "60")
        #expect(course.fractionsText == "20")
        #expect(course.alphaBetaText == "1.5")
    }

    @Test("α/β を持つ自施設プリセットは α/β も入る")
    func applyInstitutionalWithAlphaBeta() {
        let vm = MultiCourseViewModel()
        let course = vm.courses[0]
        course.alphaBetaText = "10"
        vm.apply(.institutional(institutional(alphaBeta: 1.5)), to: course)
        #expect(course.alphaBetaText == "1.5")
    }

    @Test("α/β を持たない自施設プリセットは α/β を変えない")
    func applyInstitutionalWithoutAlphaBeta() {
        let vm = MultiCourseViewModel()
        let course = vm.courses[0]
        course.alphaBetaText = "10"
        vm.apply(.institutional(institutional(alphaBeta: nil)), to: course)
        #expect(course.totalDoseText == "60")
        #expect(course.fractionsText == "20")
        #expect(course.alphaBetaText == "10", "α/β を変えてはいけない")
    }
}
