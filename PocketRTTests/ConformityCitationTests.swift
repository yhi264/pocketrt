import Testing
import Foundation
@testable import PocketRT

/// 品質指標の逸脱判定の帰属。
///
/// 判定は「Per protocol / Minor / Major」という、プリセット表示より強い
/// 臨床的な言明をする。その根拠が利用者に確認できることを固定する。
/// 2026-08-14 の手動確認で、判定表の出典がアプリ内から確認できない
/// ことが判明したため追加した。
@Suite("逸脱判定の帰属")
struct ConformityCitationTests {

    /// `.custom` は登録された利用者定義プロトコルという動的なデータなので、
    /// 固定の一覧として列挙できない（できてもいけない。テストデータで
    /// 代表させると「利用者定義にも citations 等が持てる」という誤った
    /// 前提を持ち込みかねない）。ここでの「全プロトコル」は `.none` と
    /// 内蔵（`BuiltInProtocol.allCases`）に限る。
    private var allNonCustomSelections: [ProtocolSelection] {
        [.none] + BuiltInProtocol.allCases.map(ProtocolSelection.builtIn)
    }

    @Test("判定に使う両プロトコルが出典として登録されている")
    func bothProtocolsAreCited() {
        let ids = Set(Citations.conformity.map(\.id))
        #expect(ids == ["rtog0813", "rtog0915"])
    }

    @Test("両プロトコルの出典が一次文献として同定されている")
    func conformityCitationsArePrimary() {
        for c in Citations.conformity {
            #expect(c.kind == .primary, "\(c.id) が一次文献として同定されていない")
            #expect(c.pmid != nil, "\(c.id) に PMID がない")
            #expect(c.url != nil, "\(c.id) に参照先がない")
        }
    }

    @Test("内蔵プロトコルは必ず出典と説明を持つ")
    func judgingProtocolsCarryAttribution() {
        // `summary` は `BuiltInProtocol` では非 Optional（型として必ず持つ）
        // なので nil チェックは不要。ここでは citations だけを確認する。
        for p in BuiltInProtocol.allCases {
            #expect(!p.citations.isEmpty, "\(p.rawValue) に出典がない")
        }
    }

    @Test("判定しないときは出典も説明も出さない")
    func noneCarriesNothing() {
        #expect(ProtocolSelection.none.citations.isEmpty)
        #expect(ProtocolSelection.none.summary == nil)
    }

    @Test("プロトコルの選択と出典の対応が入れ替わっていない")
    func protocolMapsToItsOwnCitation() {
        #expect(ProtocolSelection.builtIn(.rtog0915).citations.map(\.id) == ["rtog0915"])
        #expect(ProtocolSelection.builtIn(.rtog0813).citations.map(\.id) == ["rtog0813"])
    }

    @Test("利用者定義は出典を持てない（型として持てない。実行時のガードではない）")
    func customCarriesNoAttribution() {
        // .custom は id だけを持つ（値のコピーではない。外部レビュー指摘により変更。
        // PlanQualityViewModel が customProtocols から都度 id で解決する）。
        // この型単体では名前を解決できないため、displayName/menuLabel の
        // 具体的な値はここでは検証しない（PlanQualityViewModelTests が担当）。
        let selection = ProtocolSelection.custom("c1")
        #expect(selection.citations.isEmpty)
        #expect(selection.summary == nil)
        #expect(selection.studiedSchedules == nil)
        #expect(selection.selectionDetail == nil)
    }

    @Test("判定用の文献がプリセットの出典一覧に混ざっていない")
    func conformityCitationsAreNotPresetCitations() {
        let presetIDs = Set(Citations.all.map(\.id))
        for c in Citations.conformity {
            #expect(!presetIDs.contains(c.id),
                    "\(c.id) がプリセットの出典に混入している")
        }
    }

    @Test("byID は判定用の文献も引ける")
    func byIDFindsConformityCitations() {
        // all だけを探していると、呼び出し元が増えたときに黙って nil を返す
        #expect(Citations.byID("rtog0813")?.pmid == "30943123")
        #expect(Citations.byID("rtog0915")?.pmid == "26530743")
    }

    @Test("表の由来の説明が、論文そのものではないことを述べている")
    func provenanceDistinguishesTableFromPapers() {
        // 判定表はプロトコル文書にあり、公表論文には載っていない。
        // 「PMID を開けば表を確認できる」と読めてはならない。
        let note = String(localized: ConformityCriteria.provenanceNote)
        #expect(note.contains("プロトコル文書"))
        #expect(note.contains("この表そのものは含みません"))
    }

    @Test("選択肢に部位と線量分割が併記される")
    func selectionShowsSiteAndSchedule() {
        // 試験番号だけでは、どの部位のどの線量分割に対する基準なのかが
        // 選ぶ時点で分からない。部位は displayName に、線量分割はその下に出す。
        #expect(ProtocolSelection.builtIn(.rtog0915).displayName.contains("末梢"))
        #expect(ProtocolSelection.builtIn(.rtog0813).displayName.contains("中心"))
        #expect(ProtocolSelection.builtIn(.rtog0915).selectionDetail == "34 Gy/1 Fr・48 Gy/4 Fr")
        #expect(ProtocolSelection.builtIn(.rtog0813).selectionDetail == "50〜60 Gy/5 Fr")
    }

    @Test("判定しないは線量分割を出さない")
    func noneHasNoSelectionDetail() {
        #expect(ProtocolSelection.none.selectionDetail == nil)
        // 畳んだ表示にも余計な区切りが出ないこと
        #expect(ProtocolSelection.none.menuLabel == ProtocolSelection.none.displayName)
    }

    @Test("プルダウンの行は部位と線量分割の両方を含む")
    func menuLabelCarriesBothSiteAndSchedule() {
        // 畳んだときは displayName だけを出すので、行が長くても
        // 選択後の表示は短いままになる
        for p in allNonCustomSelections {
            #expect(p.menuLabel.hasPrefix(p.displayName))
            // 頭部定位照射は検討された線量分割を持たない（仕様 §3.1）ので
            // selectionDetail は空文字列になる（nil ではない。BuiltInProtocol.
            // selectionDetail は非 Optional）。空文字列に対する contains の
            // 主張は無意味なので、nil と同様にスキップする。
            // （Foundation を import した String.contains("") は false を返す
            // ため、素通しすると常にここで失敗する）
            guard let detail = p.selectionDetail, !detail.isEmpty else { continue }
            #expect(p.menuLabel.contains(detail), "\(p.displayName) の行に線量分割が無い")
        }
    }

    @Test("選択肢の線量分割は検討された線量分割と一致する")
    func selectionDetailMatchesStudiedSchedules() {
        // selectionDetail は studiedSchedules から導く。別々に持つと、
        // 片方だけ直したときに表示と判定が食い違う。
        for p in allNonCustomSelections {
            guard let schedules = p.studiedSchedules else {
                #expect(p.selectionDetail == nil)
                continue
            }
            let detail = p.selectionDetail ?? ""
            for s in schedules {
                #expect(detail.contains(s.compactLabel),
                        "\(p.displayName) の表示に \(s.compactLabel) が無い")
                // 分割数が表示に含まれること（判定が使う値と同じもの）
                #expect(s.compactLabel.contains("/\(s.fractions) Fr"))
            }
        }
    }

    @Test("判定表が線量分割によらないことが示されている")
    func scopeIsStatedAsFractionationIndependent() {
        // RTOG 0915 は 34 Gy/1 Fr と 48 Gy/4 Fr の 2 群を持つ。群が併記されていると
        // 「どちらの群に対する基準か」が読み取れない。表の量は比と処方線量比だけで、
        // 絶対線量を含まないので群によらず共通である。それを述べていること。
        let note = String(localized: ConformityCriteria.scopeNote)
        #expect(note.contains("絶対線量を含みません"))
        #expect(note.contains("共通"))
    }

    @Test("R50% の定義が原典間で食い違うことと、採用した定義が示されている")
    func r50DefinitionDiscrepancyIsDisclosed() {
        // RTOG 0915 の本文は R50% を「34 Gy または 12 Gy の等線量体積」と記しており、
        // どちらも処方線量の 50% にならない。アプリは表の見出しと 0813 に従う。
        // この差を伝えないと、0915 の本文どおりに計算した人がアプリと違う値を得る。
        let note = String(localized: ConformityCriteria.r50DefinitionNote)
        #expect(note.contains("食い違"))
        // 「処方線量の 50%」だけを見ると、食い違いを述べた側の文
        // （いずれも処方線量の 50% になりません）でも成立してしまう。
        // アプリが何を採用したかの一文そのものを固定する。
        #expect(note.contains("本アプリは"))
        #expect(note.contains("「処方線量の 50% の等線量体積 ÷ PTV 体積」として計算します"))
        // 0915 側の記述を挙げていること。これが無いと食い違いの内容が伝わらない
        #expect(note.contains("34 Gy"))
        #expect(note.contains("12 Gy"))
    }

    @Test("判定表は絶対線量を持たない")
    func tableContainsNoAbsoluteDose() {
        // scopeNote の主張がコードの実体と一致していることを固定する。
        // 表に絶対線量の列が足されたら、この主張は嘘になる。
        for row in ConformityCriteria.table {
            // R100% / R50% は比、D2cm は処方線量比 %。いずれも Gy ではない。
            #expect(row.r50None > 0 && row.r50None < 10, "R50% が比の範囲を外れている")
            #expect(row.d2cmNone > 0 && row.d2cmNone <= 100, "D2cm が % の範囲を外れている")
            #expect(row.d2cmMinor > 0 && row.d2cmMinor <= 100, "D2cm が % の範囲を外れている")
        }
    }

    @Test("原典の誤植を補正したことが利用者に示されている")
    func correctionIsDisclosed() {
        // 黙って直すと、原典と突き合わせた人が食い違いに戸惑う
        let note = String(localized: ConformityCriteria.correctionNote)
        #expect(note.contains("誤植"))
    }

    // MARK: - 頭部定位照射（Shaw 1993）の出典（D4 Task 1）

    @Test("Shaw 1993 が頭部定位照射の出典として登録されている")
    func shaw1993IsCranialCitation() {
        let ids = Set(Citations.cranialConformity.map(\.id))
        #expect(ids == ["shaw1993"])
    }

    @Test("Shaw 1993 は一次文献として PMID つきで同定されている")
    func shaw1993IsPrimaryWithPMID() {
        let c = Citations.shaw1993
        #expect(c.kind == .primary)
        #expect(c.pmid == "8262852")
        #expect(c.url != nil)
    }

    @Test("頭部定位照射（BuiltInProtocol.cranialSRS）の出典は Shaw 1993 のみ")
    func cranialProtocolCitesOnlyShaw1993() {
        #expect(ProtocolSelection.builtIn(.cranialSRS).citations.map(\.id) == ["shaw1993"])
    }

    @Test("頭部定位照射の出典が肺 SBRT の出典（Citations.conformity）に混入していない")
    func shaw1993IsNotMixedWithLungSBRTCitations() {
        // 0813 / 0915 の provenanceNote は「論文はこの表そのものを含まない」と
        // 述べるが、Shaw 1993 は逆（論文本文に判定基準がある）。混ぜると
        // provenanceNote の主張が Shaw 1993 について誤りになる。
        let lungIDs = Set(Citations.conformity.map(\.id))
        #expect(!lungIDs.contains("shaw1993"))
    }

    @Test("byID は頭部定位照射の出典も引ける")
    func byIDFindsCranialCitation() {
        #expect(Citations.byID("shaw1993")?.pmid == "8262852")
    }

    @Test("頭部定位照射は検討された線量分割を持たない（仕様 §3.1）")
    func cranialProtocolHasNoStudiedSchedules() {
        #expect(BuiltInProtocol.cranialSRS.studiedSchedules.isEmpty)
        #expect(ProtocolSelection.builtIn(.cranialSRS).studiedSchedules == [])
        #expect(ProtocolSelection.builtIn(.cranialSRS).expectedFractions == [])
    }

    @Test("頭部定位照射の summary は 1993 年の文書であることに触れている")
    func cranialSummaryMentionsEra() {
        let summary = String(localized: BuiltInProtocol.cranialSRS.summary)
        #expect(summary.contains("1993"))
    }

    @Test("頭部定位照射のプルダウン表示に余計な空白が残らない（selectionDetail が空のため）")
    func cranialMenuLabelHasNoTrailingWhitespaceArtifact() {
        let label = BuiltInProtocol.cranialSRS.menuLabel
        #expect(label == BuiltInProtocol.cranialSRS.displayName)
    }

    @Test("頭部定位照射の由来説明は、判定基準が論文本文そのものにあることを述べている")
    func cranialProvenanceNoteStatesTableIsInThePaper() {
        // 0813 / 0915（provenanceNote）とは逆に、Shaw 1993 は論文本文に基準がある。
        let note = String(localized: ConformityCriteria.cranialProvenanceNote)
        #expect(note.contains("本文そのものに"))
    }

    // MARK: - Task 2「判定していないものを明示する」

    // UI 整理（判定パネルの注記過多への対応）で、単一の注記だったものを
    // 常時表示側（cranialJudgesTwoOfThreeNote）と折りたたみ側
    // （cranialCoverageDetailNote）に分割した。「2 つだけ判定している」という
    // 事実は常時表示側に残さなければならない（黙って 2 基準だけ判定すると、
    // 利用者は 3 基準すべてを満たしたと誤解しうるため）。

    @Test("常時表示側: Coverage を含む 3 基準中、本アプリが判定するのは 2 つだけであることが述べられている")
    func cranialJudgesTwoOfThreeNoteStatesTheCount() {
        let note = String(localized: ConformityCriteria.cranialJudgesTwoOfThreeNote)
        #expect(note.contains("Coverage"))
        #expect(note.contains("3"))
        #expect(note.contains("2"))
    }

    @Test("折りたたみ側: Coverage が何であり、なぜ判定できないかが説明されている")
    func cranialCoverageDetailNoteExplainsWhy() {
        let note = String(localized: ConformityCriteria.cranialCoverageDetailNote)
        #expect(note.contains("Coverage"))
        #expect(note.contains("判定していません") || note.contains("判定しません"))
    }

    @Test("境界を安全側に倒していることの明示が、原典が定めていない具体的な境界に触れている")
    func cranialBoundarySafetyNoteNamesTheUndefinedBoundaries() {
        let note = String(localized: ConformityCriteria.cranialBoundarySafetyNote)
        #expect(note.contains("安全側"))
        #expect(note.contains("2.5"))
        #expect(note.contains("0.9"))
    }

    @Test("1993 年の文書であることの明示に、年と現在の実務との関係を利用者が判断する旨が含まれる")
    func cranialEraNoteStatesTheYearAndImplication() {
        let note = String(localized: ConformityCriteria.cranialEraNote)
        #expect(note.contains("1993"))
        #expect(note.contains("利用者が"))
    }

    @Test("GI の但し書きが、多発病変で意味をなさないことがある旨を述べている")
    func giCaveatNoteStatesTheLimitation() {
        let note = String(localized: ConformityCriteria.giCaveatNote)
        #expect(note.contains("近接"))
        #expect(note.contains("意味をなさない"))
    }

    // MARK: - TROG SRS Technical Working Group（GI の但し書きの根拠。判定の根拠ではない）

    @Test("TROG が頭部定位照射の限界の根拠として登録されている")
    func trogIsCranialLimitationCitation() {
        let ids = Set(Citations.cranialLimitations.map(\.id))
        #expect(ids == ["trog2026_srs_working_group"])
    }

    @Test("TROG は DOI を持ち一次文献として同定されている（PMID は無い）")
    func trogIsPrimaryViaDOI() {
        let c = Citations.trog2026SRSWorkingGroup
        #expect(c.kind == .primary)
        #expect(c.doi == "10.1111/1754-9485.70064")
        #expect(c.pmid == nil)
        #expect(c.url != nil)
    }

    @Test("TROG は判定基準の出典（cranialConformity）に混入していない。役割が違うため")
    func trogIsNotMixedWithJudgementCriteriaCitations() {
        let judgementIDs = Set(Citations.cranialConformity.map(\.id))
        #expect(!judgementIDs.contains("trog2026_srs_working_group"))
        let limitationIDs = Set(Citations.cranialLimitations.map(\.id))
        #expect(!limitationIDs.contains("shaw1993"), "判定基準の出典が限界の根拠の節に混入している")
    }

    @Test("byID は頭部定位照射の限界の根拠（TROG）も引ける")
    func byIDFindsCranialLimitationCitation() {
        #expect(Citations.byID("trog2026_srs_working_group")?.doi == "10.1111/1754-9485.70064")
    }
}
