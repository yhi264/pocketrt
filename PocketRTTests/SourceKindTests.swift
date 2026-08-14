import Testing
import Foundation
@testable import PocketRT

@Suite("出典の 3 段階")
struct SourceKindTests {

    @Test("pmid があれば primary")
    func primaryByPMID() {
        let c = Citation(id: "t", shortLabel: "T", pmid: "12345")
        #expect(c.kind == .primary)
    }

    @Test("guidelineNote だけなら guideline")
    func guidelineKind() {
        let c = Citation(id: "t", shortLabel: "T", guidelineNote: "ガイドラインの記載")
        #expect(c.kind == .guideline)
        #expect(c.hasPrimarySource == false)
    }

    @Test("どちらもなければ unsourced")
    func unsourcedKind() {
        let c = Citation(id: "t", shortLabel: "T", unsourcedNote: "根拠不明")
        #expect(c.kind == .unsourced)
    }

    @Test("ガイドライン由来の 5 件が guideline になっている")
    func guidelineCitationsAreClassified() {
        let expected = ["jastro_head_neck", "jastro_prostate", "jastro_breast",
                        "jastro_whole_brain", "jastro_acoustic"]
        for id in expected {
            let c = Citations.byID(id)
            #expect(c != nil, "見つからない: \(id)")
            #expect(c?.kind == .guideline, "guideline でない: \(id)")
        }
    }

    @Test("慣用レジメンの Citation は残っていない")
    func conventionalRegimenRemoved() {
        #expect(Citations.byID("conventional_regimen") == nil)
        #expect(!FractionationPresets.all.contains { $0.citations.contains { $0.id == "conventional_regimen" } })
    }

    @Test("Citations.all が定義済みの全件を列挙している")
    func allListsEveryCitation() {
        // プリセットが参照する出典はすべて all に含まれる
        for p in FractionationPresets.all {
            for c in p.citations {
                #expect(Citations.byID(c.id) != nil, "all に未登録: \(c.id)")
            }
        }
    }
}
