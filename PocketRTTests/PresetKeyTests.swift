import Testing
import Foundation
@testable import PocketRT

@Suite("内蔵プリセットの安定キー")
struct PresetKeyTests {

    @Test("すべてのプリセットが id を持ち、一意である")
    func idsAreUniqueAndNonEmpty() {
        let ids = FractionationPresets.all.map(\.id)
        #expect(ids.count == 18)
        #expect(!ids.contains(where: { $0.isEmpty }))
        #expect(Set(ids).count == ids.count)
    }

    @Test("id は英小文字・数字・アンダースコアのみ")
    func idsUseStableCharacters() {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        for p in FractionationPresets.all {
            #expect(p.id.unicodeScalars.allSatisfy { allowed.contains($0) }, "不正な id: \(p.id)")
        }
    }

    @Test("id は静的に決まっており、配列を作り直しても変わらない")
    func idsAreStableAcrossInstances() {
        let first = FractionationPresets.all.map(\.id)
        let again = FractionationPresets.all.map(\.id)
        #expect(first == again)
        // 同じ値で作り直しても id が変わらないことを、既知のキーで確かめる
        #expect(FractionationPresets.all.contains { $0.id == "conventional_head_neck" })
    }
}
