import Testing
import Foundation
@testable import PocketRT

@Suite("プリセットの適用")
struct PresetSelectionTests {

    private func institutional(alphaBeta: Double?) -> InstitutionalPreset {
        InstitutionalPreset(id: "i1", name: "自施設 前立腺", totalDose: 60.0,
                            fractions: 20, alphaBeta: alphaBeta, note: nil,
                            createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test("内蔵プリセットを適用すると線量・分割数・α/β が入る")
    func applyBuiltIn() {
        let vm = SimpleCalcViewModel()
        let p = FractionationPresets.all.first { $0.id == "hypo_prostate_moderate" }!
        vm.apply(.builtIn(p))
        #expect(vm.totalDoseText == "60")
        #expect(vm.fractionsText == "20")
        #expect(vm.alphaBetaText == "1.5")
    }

    @Test("α/β を持つ自施設プリセットは α/β も入る")
    func applyInstitutionalWithAlphaBeta() {
        let vm = SimpleCalcViewModel()
        vm.alphaBetaText = "10"
        vm.apply(.institutional(institutional(alphaBeta: 1.5)))
        #expect(vm.totalDoseText == "60")
        #expect(vm.fractionsText == "20")
        #expect(vm.alphaBetaText == "1.5")
    }

    @Test("α/β を持たない自施設プリセットは α/β を変えない")
    func applyInstitutionalWithoutAlphaBeta() {
        let vm = SimpleCalcViewModel()
        vm.alphaBetaText = "10"
        vm.apply(.institutional(institutional(alphaBeta: nil)))
        #expect(vm.totalDoseText == "60")
        #expect(vm.fractionsText == "20")
        #expect(vm.alphaBetaText == "10", "α/β を変えてはいけない")
    }

    @Test("自施設プリセットは出典を持たず、名前を返す")
    func institutionalHasNoCitations() {
        let vm = SimpleCalcViewModel()
        vm.apply(.institutional(institutional(alphaBeta: 1.5)))
        #expect(vm.activeCitations.isEmpty, "自施設プリセットに出典を帰属させてはいけない")
        #expect(vm.activeInstitutionalName == "自施設 前立腺")
    }

    @Test("値を手で変えると自施設プリセットの帰属も消える")
    func institutionalNameClearsOnEdit() {
        let vm = SimpleCalcViewModel()
        vm.apply(.institutional(institutional(alphaBeta: 1.5)))
        vm.totalDoseText = "61"
        #expect(vm.activeInstitutionalName == nil)
    }

    @Test("α/β だけを変えても帰属は残る（同じ処方を別の組織の α/β で見る正当な使い方のため）")
    func attributionSurvivesAlphaBetaEdit() {
        let vm = SimpleCalcViewModel()
        vm.apply(.institutional(institutional(alphaBeta: 1.5)))
        #expect(vm.activeInstitutionalName == "自施設 前立腺")

        // 晩期反応組織の α/β で同じ処方を見る
        vm.alphaBetaText = "3"
        #expect(vm.activeInstitutionalName == "自施設 前立腺",
                "α/β の変更で帰属を消してはいけない。仕様である")
    }

    @Test("内蔵プリセットも α/β だけの変更では出典が残る")
    func builtInCitationSurvivesAlphaBetaEdit() {
        let vm = SimpleCalcViewModel()
        let p = FractionationPresets.all.first { $0.id == "hypo_prostate_moderate" }!
        vm.apply(.builtIn(p))
        #expect(!vm.activeCitations.isEmpty)

        vm.alphaBetaText = "3"
        #expect(!vm.activeCitations.isEmpty, "α/β の変更で出典を消してはいけない。仕様である")
    }

    @Test("総線量を変えると帰属が消える(誤帰属を防ぐ判定は生きている)")
    func attributionClearsOnDoseEdit() {
        let vm = SimpleCalcViewModel()
        vm.apply(.institutional(institutional(alphaBeta: 1.5)))
        vm.totalDoseText = "61"
        #expect(vm.activeInstitutionalName == nil)
    }

    @Test("分割数を変えると帰属が消える")
    func attributionClearsOnFractionsEdit() {
        let vm = SimpleCalcViewModel()
        vm.apply(.institutional(institutional(alphaBeta: 1.5)))
        vm.fractionsText = "21"
        #expect(vm.activeInstitutionalName == nil)
    }

    @Test("小数第3位を持つ自施設プリセットでも、適用直後は帰属が表示される")
    func attributionSurvivesRoundingOfDisplayString() {
        let vm = SimpleCalcViewModel()
        // %.2f で丸めると 60.57 になる値。丸め前の値と完全一致で比較すると
        // 適用直後から自己不一致になり、帰属が一度も表示されない
        let p = InstitutionalPreset(id: "r1", name: "端数あり", totalDose: 60.567,
                                    fractions: 20, alphaBeta: nil, note: nil,
                                    createdAt: Date(timeIntervalSince1970: 0))
        vm.apply(.institutional(p))
        #expect(vm.totalDoseText == "60.57")
        #expect(vm.activeInstitutionalName == "端数あり",
                "表示文字列の丸めで帰属が消えてはいけない")
    }

    @Test("許容差を超える編集では帰属が消える")
    func attributionClearsBeyondTolerance() {
        let vm = SimpleCalcViewModel()
        vm.apply(.institutional(institutional(alphaBeta: 1.5)))   // totalDose 60.0
        vm.totalDoseText = "60.05"     // 許容差 0.01 を超える
        #expect(vm.activeInstitutionalName == nil)
    }

    @Test("ScheduleViewModel でも、小数第3位を持つ自施設プリセットで適用直後に帰属が表示される")
    func scheduleViewModelSurvivesRoundingOfDisplayString() {
        let vm = ScheduleViewModel()
        let p = InstitutionalPreset(id: "r2", name: "端数あり", totalDose: 60.567,
                                    fractions: 20, alphaBeta: nil, note: nil,
                                    createdAt: Date(timeIntervalSince1970: 0))
        vm.apply(.institutional(p))
        #expect(vm.totalDoseText == "60.57")
        #expect(vm.activeInstitutionalName == "端数あり",
                "表示文字列の丸めで帰属が消えてはいけない")
    }
}
