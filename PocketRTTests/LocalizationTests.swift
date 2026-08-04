import Testing
@testable import PocketRT

@Suite("ローカライズ構造")
struct LocalizationStructureTests {

    @Test("PresetCategory の id は ASCII の安定キー（表示名ではない）")
    func categoryIDsAreStableKeys() {
        let ids = PresetCategory.allCases.map(\.id)
        #expect(ids == ["conventional", "hypofractionation", "srt", "sbrt", "palliative"])
        for id in ids {
            #expect(id.allSatisfy { $0.isASCII }, "id に非 ASCII 文字: \(id)")
        }
    }

    @Test("PresetCategory の displayName は id と異なる")
    func displayNameIsSeparateFromID() {
        for cat in PresetCategory.allCases {
            #expect(cat.displayName != cat.id)
            #expect(!cat.displayName.isEmpty)
        }
    }

    @Test("全カテゴリにプリセットが存在する")
    func everyCategoryHasPresets() {
        for cat in PresetCategory.allCases {
            #expect(!FractionationPresets.byCategory(cat).isEmpty, "空のカテゴリ: \(cat.id)")
        }
    }
}
