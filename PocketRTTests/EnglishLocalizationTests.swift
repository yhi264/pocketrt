import Testing
import Foundation
@testable import PocketRT

/// 英語ロケールでの表示を数点だけ固定する。
///
/// カタログの網羅性（全キーに en があるか）は `tools/sync-strings.sh` が見る。
/// ここで見るのは、**カタログがアプリに届いているか**という別の問い。
/// 訳がカタログにあってもビルド設定から `en` が落ちれば日本語が出るが、
/// カタログを読むだけの検査ではそれを検出できない。
@Suite("英語ロケールの表示")
struct EnglishLocalizationTests {

    private func english(_ resource: LocalizedStringResource) -> String {
        var localized = resource
        localized.locale = Locale(identifier: "en")
        return String(localized: localized)
    }

    @Test("画面の基本語が英語になる")
    func coreTermsAreEnglish() {
        #expect(english("総線量") == "Total dose")
        #expect(english("分割数") == "Fractions")
        #expect(english("処方線量") == "Prescription dose")
        #expect(english("出典") == "Sources")
        #expect(english("判定") == "Assessment")
    }

    @Test("プリセットの部位名が英語になる")
    func presetSitesAreEnglish() {
        let brainMets = FractionationPresets.all.first { $0.id == "srt_brain_mets_srs_standard" }
        #expect(brainMets != nil)
        #expect(english(brainMets!.site) == "Brain metastasis, single-fraction SRS, standard")
    }

    // 出典の短縮ラベルは 2026-09-05 まで String だったため、英語環境でも
    // 「JASTRO 計画GL 2024 頭頸部」がそのまま出ていた。型を戻す退行を防ぐ。
    @Test("出典の短縮ラベルが英語になる（日本語が残らない）")
    func citationShortLabelsAreEnglish() {
        #expect(english(Citations.jastroHeadNeck.shortLabel) == "JASTRO Planning GL 2024, Head & Neck")
        #expect(english(Citations.stupp.shortLabel) == "Stupp regimen")
        #expect(english(Citations.boneMetsMeta.shortLabel) == "Rich/Chow 2018 meta-analysis")

        for citation in Citations.all {
            let label = english(citation.shortLabel)
            // contains(where:) は rethrows なので、#expect の中に置くと
            // 「throw しうる呼び出し」と見なされてコンパイルできない。先に畳む。
            let hasJapanese = label.contains { $0.isJapanese }
            #expect(!hasJapanese, "英語ラベルに日本語が残っている: \(label)")
        }
    }

    // ガイドラインの引用句は原文（日本語）を残す方針のため、日本語が
    // 含まれていること自体は正しい。英語の枠が付いているかを見る。
    @Test("ガイドラインの引用は原文を残したうえで英語の説明が付く")
    func guidelineNotesKeepJapaneseQuoteWithEnglishFrame() {
        let note = english(Citations.jastroHeadNeck.guidelineNote!)
        #expect(note.hasPrefix("JASTRO Radiotherapy Planning Guidelines 2024"))
        #expect(note.contains("「70 Gy/35 回/7 週の通常分割照射が標準分割照射法である」"))
        #expect(note.contains("no official English edition"))
    }
}

private extension Character {
    /// ひらがな・カタカナ・CJK 統合漢字のいずれかか。
    var isJapanese: Bool {
        guard let scalar = unicodeScalars.first?.value else { return false }
        return (0x3040...0x30FF).contains(scalar) || (0x4E00...0x9FFF).contains(scalar)
    }
}
