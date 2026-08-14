import Testing
@testable import PocketRT

/// 品質指標の逸脱判定の帰属。
///
/// 判定は「Per protocol / Minor / Major」という、プリセット表示より強い
/// 臨床的な言明をする。その根拠が利用者に確認できることを固定する。
/// 2026-08-14 の手動確認で、判定表の出典がアプリ内から確認できない
/// ことが判明したため追加した。
@Suite("逸脱判定の帰属")
struct ConformityCitationTests {

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

    @Test("判定するプロトコルは必ず出典と説明を持つ")
    func judgingProtocolsCarryAttribution() {
        for p in ProtocolSelection.allCases where p != .none {
            #expect(!p.citations.isEmpty, "\(p.rawValue) に出典がない")
            #expect(p.summary != nil, "\(p.rawValue) に説明がない")
        }
    }

    @Test("判定しないときは出典も説明も出さない")
    func noneCarriesNothing() {
        #expect(ProtocolSelection.none.citations.isEmpty)
        #expect(ProtocolSelection.none.summary == nil)
    }

    @Test("プロトコルの選択と出典の対応が入れ替わっていない")
    func protocolMapsToItsOwnCitation() {
        #expect(ProtocolSelection.rtog0915.citations.map(\.id) == ["rtog0915"])
        #expect(ProtocolSelection.rtog0813.citations.map(\.id) == ["rtog0813"])
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
        #expect(ProtocolSelection.rtog0915.displayName.contains("末梢"))
        #expect(ProtocolSelection.rtog0813.displayName.contains("中心"))
        #expect(ProtocolSelection.rtog0915.selectionDetail == "34 Gy/1 Fr・48 Gy/4 Fr")
        #expect(ProtocolSelection.rtog0813.selectionDetail == "50〜60 Gy/5 Fr")
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
        for p in ProtocolSelection.allCases {
            #expect(p.menuLabel.hasPrefix(p.displayName))
            guard let detail = p.selectionDetail else { continue }
            #expect(p.menuLabel.contains(detail), "\(p.rawValue) の行に線量分割が無い")
        }
    }

    @Test("選択肢の線量分割は検討された線量分割と一致する")
    func selectionDetailMatchesStudiedSchedules() {
        // selectionDetail は studiedSchedules から導く。別々に持つと、
        // 片方だけ直したときに表示と判定が食い違う。
        for p in ProtocolSelection.allCases {
            guard let schedules = p.studiedSchedules else {
                #expect(p.selectionDetail == nil)
                continue
            }
            let detail = p.selectionDetail ?? ""
            for s in schedules {
                #expect(detail.contains(s.compactLabel),
                        "\(p.rawValue) の表示に \(s.compactLabel) が無い")
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
}
