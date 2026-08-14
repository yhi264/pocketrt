import Testing
import Foundation
@testable import PocketRT

@Suite("ローカライズ化した文字列が値として保たれている")
struct LocalizationModelTests {

    @Test("α/β プリセットは 8 件で、うち 4 件が注記を持つ")
    func alphaBetaPresetCounts() {
        #expect(AlphaBetaPresets.all.count == 8)
        #expect(AlphaBetaPresets.all.filter { $0.note != nil }.count == 4)
    }

    @Test("α/β プリセットのラベルは空でない")
    func alphaBetaLabelsAreNonEmpty() {
        for p in AlphaBetaPresets.all {
            #expect(!String(localized: p.label).isEmpty)
        }
    }

    @Test("腫瘍（一般）の α/β は 10 で注記はデフォルト")
    func tumourGeneralPreset() {
        let p = AlphaBetaPresets.all.first { String(localized: $0.label) == "腫瘍（一般）" }
        #expect(p != nil)
        #expect(p?.value == 10)
        #expect(p.flatMap { $0.note.map { String(localized: $0) } } == "デフォルト")
    }

    @Test("線量分割プリセットは 18 件で、うち 2 件が注記を持つ")
    func fractionationPresetCounts() {
        #expect(FractionationPresets.all.count == 18)
        #expect(FractionationPresets.all.filter { $0.note != nil }.count == 2)
    }

    @Test("線量分割プリセットの部位名は空でない")
    func presetSitesAreNonEmpty() {
        for p in FractionationPresets.all {
            #expect(!String(localized: p.site).isEmpty)
        }
    }

    @Test("頭頸部根治は 70 Gy / 35 Fr")
    func headNeckPreset() {
        let p = FractionationPresets.all.first { String(localized: $0.site) == "頭頸部根治" }
        #expect(p != nil)
        #expect(p?.totalDose == 70.0)
        #expect(p?.fractions == 35)
    }

    @Test("AlphaBetaPreset は id で等価判定される")
    func alphaBetaEquatableByID() {
        let id = UUID()
        let a = AlphaBetaPreset(id: id, label: "A", value: 1)
        let b = AlphaBetaPreset(id: id, label: "B", value: 2)
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
    }

    @Test("出典未特定の citation は formattedReference に注記を返す")
    func unsourcedFormattedReference() {
        let c = Citation(id: "test", shortLabel: "テスト", unsourcedNote: "慣用レジメンです")
        #expect(c.hasPrimarySource == false)
        #expect(c.formattedReference == "慣用レジメンです")
    }

    @Test("一次文献がある citation は formattedReference に書誌を返す")
    func sourcedFormattedReference() {
        let c = Citation(id: "test", shortLabel: "テスト",
                         authors: "Nagata Y, et al.", journal: "Int J Radiat Oncol Biol Phys",
                         year: 2015, pmid: "26104943")
        #expect(c.hasPrimarySource == true)
        #expect(c.formattedReference == "Nagata Y, et al. Int J Radiat Oncol Biol Phys. 2015.")
    }

    @Test("すべての出典が一次文献かガイドラインに基づく")
    func everyCitationHasAKnownSource() {
        for c in Citations.all {
            #expect(c.kind != .unsourced, "根拠が同定できていない: \(c.shortLabel)")
        }
    }

    @Test("解説は 8 セクションで、id は一意")
    func referenceSectionCount() {
        #expect(ReferenceContent.sections.count == 8)
        let ids = ReferenceContent.sections.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("解説の見出しと本文は空でない")
    func referenceSectionTextIsNonEmpty() {
        for s in ReferenceContent.sections {
            #expect(!String(localized: s.title).isEmpty, "見出しが空: \(s.id)")
            #expect(!String(localized: s.body).isEmpty, "本文が空: \(s.id)")
        }
    }

    @Test("扱わないこと章は治療期間の補正を実装していない旨を含む")
    func limitsSectionMentionsOTT() {
        let s = ReferenceContent.sections.first { $0.id == "limits" }
        #expect(s != nil)
        let body = s.map { String(localized: $0.body) } ?? ""
        #expect(body.contains("治療期間（OTT）の延長に対する生物学的補正は実装していません"))
    }
}
