import Testing
import Foundation
@testable import PocketRT

@Suite("Citation データ整合性")
struct CitationDataTests {

    @Test("全プリセットが citation を持つ")
    func allPresetsHaveCitation() {
        for p in FractionationPresets.all {
            #expect(!p.citations.isEmpty, "citations 未設定: \(p.regimenLabel)")
            for c in p.citations {
                #expect(!String(localized: c.shortLabel).isEmpty, "shortLabel 未設定: \(p.regimenLabel)")
            }
        }
    }

    @Test("citation は pmid / doi / guidelineNote / unsourcedNote のいずれかを必ず持つ")
    func citationHasProvenance() {
        for c in Citations.all {
            let hasPrimary = (c.pmid != nil) || (c.doi != nil)
            let hasNote = (c.guidelineNote != nil) || (c.unsourcedNote != nil)
            #expect(hasPrimary || hasNote, "根拠なし: \(String(localized: c.shortLabel))")
        }
    }

    @Test("Citation の id は一意")
    func citationIDsAreUnique() {
        let ids = Citations.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("中心型肺 60Gy/8Fr の出典は JROSG10-1（JCOG0702 ではない）")
    func centralLungCitationIsJROSG() {
        let p = FractionationPresets.all.first {
            $0.category == .sbrt && $0.fractions == 8 && $0.totalDose == 60.0
        }
        #expect(p != nil)
        #expect(p?.citations.count == 1)
        #expect(p?.citations.first?.id == "jrosg10_1")
        #expect(p?.citations.first?.pmid == "28466183")
    }

    @Test("JCOG0702 はプリセットの出典として使われていない")
    func jcog0702NotUsed() {
        #expect(!FractionationPresets.all.contains { $0.citations.contains { $0.id == "jcog0702" } })
    }

    @Test("脳転移 SRS 20 Gy/1 Fr の出典は JLGK0901（RTOG 90-05 ではない）")
    func brainMetsSRS20GyCitationIsJLGK0901() {
        let p = FractionationPresets.all.first { $0.id == "srt_brain_mets_srs_standard" }
        #expect(p != nil)
        #expect(p?.totalDose == 20.0)
        #expect(p?.fractions == 1)
        #expect(p?.citations.count == 1)
        #expect(p?.citations.first?.id == "jlgk0901")
        #expect(p?.citations.first?.pmid == "24621620")
    }

    // RTOG 90-05 の線量段階は 18 / 15 / 12 Gy から 3 Gy 刻みであり、20 Gy は存在しない。
    // 20 Gy をこの文献に紐付け直す退行を防ぐ（data-sources.md §B3「訂正した誤り」4）。
    @Test("RTOG 90-05 を出典に持つプリセットは 24 Gy/1 Fr の 1 件だけ")
    func rtog9005IsUsedOnlyBy24Gy() {
        let presets = FractionationPresets.all.filter { p in
            p.citations.contains { $0.id == "rtog_90_05" }
        }
        #expect(presets.map(\.id) == ["srt_brain_mets_srs_high"])
        #expect(presets.allSatisfy { $0.totalDose == 24.0 && $0.fractions == 1 })
    }

    // 20 Gy は腫瘍体積、24 Gy は最大径で条件が付く。線量だけを出すと
    // 条件のない推奨に見えるため、両者は note を必ず持つ。
    @Test("脳転移 SRS 単回の 2 件は適用条件の note を持つ")
    func brainMetsSRSPresetsHaveConditionNote() {
        for id in ["srt_brain_mets_srs_standard", "srt_brain_mets_srs_high"] {
            let p = FractionationPresets.all.first { $0.id == id }
            #expect(p != nil, "プリセットが無い: \(id)")
            #expect(p?.note != nil, "適用条件の note が無い: \(id)")
        }
    }

    @Test("unsourcedNote を持つ citation は pmid / doi を持たない")
    func unsourcedHasNoPrimary() {
        for c in Citations.all where c.unsourcedNote != nil {
            #expect(c.pmid == nil && c.doi == nil, "慣用扱いなのに一次文献がある: \(String(localized: c.shortLabel))")
        }
    }

    @Test("食道癌根治 60Gy/30Fr は JCOG0303 と JCOG0909 の両方を出典に持つ")
    func esophagealHasBothJCOGCitations() {
        let p = FractionationPresets.all.first {
            $0.category == .conventional && $0.totalDose == 60.0 && $0.fractions == 30
        }
        #expect(p != nil)
        #expect(p?.citations.count == 2)
        #expect(p?.citations.map(\.id) == ["jcog0303", "jcog0909"])
        for c in p?.citations ?? [] {
            #expect(c.pmid != nil, "PMID 未設定: \(String(localized: c.shortLabel))")
        }
    }
}

@Suite("計算結果への出典併記")
struct ActiveCitationTests {

    private var jcog0403Preset: FractionationPreset {
        FractionationPresets.all.first { $0.citations.contains { $0.id == "jcog0403" } }!
    }

    @Test("プリセット適用直後は出典を返す")
    func citationAfterApply() {
        let vm = SimpleCalcViewModel()
        vm.apply(.builtIn(jcog0403Preset))
        #expect(vm.activeCitations.map(\.id) == ["jcog0403"])
    }

    @Test("何も適用していなければ空配列")
    func noCitationInitially() {
        let vm = SimpleCalcViewModel()
        #expect(vm.activeCitations.isEmpty)
    }

    @Test("総線量を編集すると出典が外れる（誤帰属を防ぐ）")
    func citationClearedOnDoseEdit() {
        let vm = SimpleCalcViewModel()
        vm.apply(.builtIn(jcog0403Preset))
        vm.totalDoseText = "50"
        #expect(vm.activeCitations.isEmpty)
    }

    @Test("分割数を編集すると出典が外れる")
    func citationClearedOnFractionsEdit() {
        let vm = SimpleCalcViewModel()
        vm.apply(.builtIn(jcog0403Preset))
        vm.fractionsText = "5"
        #expect(vm.activeCitations.isEmpty)
    }

    @Test("編集して元の値に戻せば出典が復活する")
    func citationRestoredWhenValuesMatchAgain() {
        let vm = SimpleCalcViewModel()
        let p = jcog0403Preset
        vm.apply(.builtIn(p))
        vm.totalDoseText = "50"
        #expect(vm.activeCitations.isEmpty)
        vm.totalDoseText = "48"
        #expect(vm.activeCitations.map(\.id) == ["jcog0403"])
    }

    @Test("ScheduleViewModel も同じ挙動")
    func scheduleViewModelBehavesSame() {
        let vm = ScheduleViewModel()
        vm.apply(.builtIn(jcog0403Preset))
        #expect(vm.activeCitations.map(\.id) == ["jcog0403"])
        vm.fractionsText = "30"
        #expect(vm.activeCitations.isEmpty)
    }

    @Test("複数出典のプリセットは両方の出典を返す")
    func multipleCitationsSurviveApply() {
        let esophagealPreset = FractionationPresets.all.first {
            $0.category == .conventional && $0.totalDose == 60.0 && $0.fractions == 30
        }!
        let vm = SimpleCalcViewModel()
        vm.apply(.builtIn(esophagealPreset))
        #expect(vm.activeCitations.map(\.id) == ["jcog0303", "jcog0909"])
    }
}
